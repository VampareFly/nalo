package com.sanjiang.nalo

import android.content.Context
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Environment
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import kotlin.math.max

/** 创建使用 CameraX 的原生预览实例，并为每个视图建立独立拍照通道。 */
class NativeCameraViewFactory(
    private val messenger: BinaryMessenger,
    private val lifecycleOwner: LifecycleOwner,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        NativeCameraView(context, viewId, messenger, lifecycleOwner)
}

/** 使用 CameraX 质量优先模式管理 Android 相机预览和照片输出。 */
private class NativeCameraView(
    private val context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    private val lifecycleOwner: LifecycleOwner,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val previewView = PreviewView(context).apply {
        scaleType = PreviewView.ScaleType.FILL_CENTER
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }
    private val channel = MethodChannel(messenger, "nalo/native_camera_$viewId")
    private val processingExecutor = Executors.newSingleThreadExecutor()
    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var ready = false

    init {
        channel.setMethodCallHandler(this)
        previewView.post { startCamera() }
    }

    override fun getView(): View = previewView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isReady" -> result.success(ready)
            "capture" -> capture(result)
            "dispose" -> {
                release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startCamera() {
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                val previewUseCase = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                val captureUseCase = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                    .setJpegQuality(100)
                    .build()
                provider.unbindAll()
                provider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    previewUseCase,
                    captureUseCase,
                )
                cameraProvider = provider
                preview = previewUseCase
                imageCapture = captureUseCase
                ready = true
            } catch (_: Exception) {
                ready = false
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun capture(result: MethodChannel.Result) {
        val capture = imageCapture
        if (!ready || capture == null) {
            result.error("camera_not_ready", "Native camera is not ready.", null)
            return
        }
        val file = File(context.cacheDir, "nalo_test_${System.currentTimeMillis()}.jpg")
        val options = ImageCapture.OutputFileOptions.Builder(file).build()
        capture.takePicture(
            options,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    processingExecutor.execute {
                        try {
                            val optimized = optimizePhoto(file)
                            ContextCompat.getMainExecutor(context).execute {
                                result.success(optimized.absolutePath)
                            }
                        } catch (error: Exception) {
                            ContextCompat.getMainExecutor(context).execute {
                                result.error("image_processing_failed", error.message, null)
                            }
                        }
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    result.error("capture_failed", exception.message, null)
                }
            },
        )
    }

    /** 将系统高清成片缩放并压缩到适合移动网络上传的尺寸。 */
    private fun optimizePhoto(source: File): File {
        val debugId = System.currentTimeMillis()
        val isDebugBuild = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        val debugDirectory = if (isDebugBuild) {
            (
                context.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)
                    ?: File(context.filesDir, "Documents")
                ).apply { mkdirs() }
        } else {
            null
        }
        debugDirectory?.let {
            source.copyTo(
                File(it, "nalo_original_$debugId.jpg"),
                overwrite = true,
            )
        }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source.absolutePath, bounds)
        var sampleSize = 1
        while (max(bounds.outWidth, bounds.outHeight) / sampleSize > 3000) {
            sampleSize *= 2
        }
        val decoded = BitmapFactory.decodeFile(
            source.absolutePath,
            BitmapFactory.Options().apply { inSampleSize = sampleSize },
        ) ?: error("Unable to decode captured photo.")
        val oriented = applyExifOrientation(decoded, source)
        val longestSide = max(oriented.width, oriented.height)
        val scaled = if (longestSide > 2500) {
            val ratio = 2500f / longestSide
            Bitmap.createScaledBitmap(
                oriented,
                (oriented.width * ratio).toInt(),
                (oriented.height * ratio).toInt(),
                true,
            )
        } else {
            oriented
        }

        val target = File(context.cacheDir, "nalo_upload_${System.currentTimeMillis()}.jpg")
        var quality = 88
        FileOutputStream(target, false).use {
            scaled.compress(Bitmap.CompressFormat.JPEG, quality, it)
        }
        while (target.length() > 5L * 1024 * 1024 && quality > 60) {
            quality = maxOf(60, quality - 8)
            FileOutputStream(target, false).use {
                scaled.compress(Bitmap.CompressFormat.JPEG, quality, it)
            }
        }

        if (scaled !== oriented) scaled.recycle()
        if (oriented !== decoded) oriented.recycle()
        decoded.recycle()
        debugDirectory?.let {
            target.copyTo(
                File(it, "nalo_upload_$debugId.jpg"),
                overwrite = true,
            )
        }
        source.delete()
        return target
    }

    @Suppress("DEPRECATION")
    private fun applyExifOrientation(bitmap: Bitmap, source: File): Bitmap {
        val orientation = ExifInterface(source.absolutePath).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
        val rotation = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (rotation == 0f) return bitmap
        return Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            Matrix().apply { postRotate(rotation) },
            true,
        )
    }

    private fun release() {
        ready = false
        val provider = cameraProvider
        val previewUseCase = preview
        val captureUseCase = imageCapture
        if (provider != null && previewUseCase != null && captureUseCase != null) {
            provider.unbind(previewUseCase, captureUseCase)
        }
        preview = null
        imageCapture = null
        cameraProvider = null
    }

    override fun dispose() {
        release()
        processingExecutor.shutdown()
        channel.setMethodCallHandler(null)
    }
}
