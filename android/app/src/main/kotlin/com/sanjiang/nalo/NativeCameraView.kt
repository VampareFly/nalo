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
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/** 创建使用 CameraX 的原生预览实例，并为每个视图建立独立拍照通道。 */
class NativeCameraViewFactory(
    private val messenger: BinaryMessenger,
    private val lifecycleOwner: LifecycleOwner,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        NativeCameraView(context, viewId, messenger, lifecycleOwner)
}

/** 使用 CameraX 管理预览，并将 Flutter 取景框映射到高清成片后裁剪输出。 */
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
            "capture" -> capture(call, result)
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

    private fun capture(call: MethodCall, result: MethodChannel.Result) {
        val capture = imageCapture
        if (!ready || capture == null) {
            result.error("camera_not_ready", "Native camera is not ready.", null)
            return
        }
        val cropRect = normalizedCropRect(call.arguments as? Map<*, *>)
        val previewWidth = previewView.width
        val previewHeight = previewView.height
        val file = File(context.cacheDir, "nalo_test_${System.currentTimeMillis()}.jpg")
        val options = ImageCapture.OutputFileOptions.Builder(file).build()
        capture.takePicture(
            options,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    processingExecutor.execute {
                        try {
                            val optimized = optimizePhoto(
                                file,
                                cropRect,
                                previewWidth,
                                previewHeight,
                            )
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

    /** 将系统高清成片映射到取景框、裁剪安全边距，再缩放压缩供预览和上传。 */
    private fun optimizePhoto(
        source: File,
        cropRect: NormalizedRect?,
        previewWidth: Int,
        previewHeight: Int,
    ): File {
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
        val cropped = cropToPreviewFrame(
            oriented,
            cropRect,
            previewWidth,
            previewHeight,
        )
        val longestSide = max(cropped.width, cropped.height)
        val scaled = if (longestSide > 2500) {
            val ratio = 2500f / longestSide
            Bitmap.createScaledBitmap(
                cropped,
                (cropped.width * ratio).toInt(),
                (cropped.height * ratio).toInt(),
                true,
            )
        } else {
            cropped
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

        scaled.recycle()
        if (cropped !== scaled) cropped.recycle()
        if (cropped !== oriented) oriented.recycle()
        if (oriented !== decoded) decoded.recycle()
        debugDirectory?.let {
            target.copyTo(
                File(it, "nalo_upload_$debugId.jpg"),
                overwrite = true,
            )
        }
        source.delete()
        return target
    }

    /** 解析 Flutter 传入的取景框归一化坐标；缺失时保留完整照片。 */
    private fun normalizedCropRect(arguments: Map<*, *>?): NormalizedRect? {
        fun number(key: String) = (arguments?.get(key) as? Number)?.toDouble()
        val x = number("x") ?: return null
        val y = number("y") ?: return null
        val width = number("width") ?: return null
        val height = number("height") ?: return null
        if (width <= 0.0 || height <= 0.0) return null
        return NormalizedRect(x, y, width, height)
    }

    /** 按 FILL_CENTER 的显示关系映射到照片，并额外保留 5% 边距避免切边。 */
    private fun cropToPreviewFrame(
        bitmap: Bitmap,
        rect: NormalizedRect?,
        previewWidth: Int,
        previewHeight: Int,
    ): Bitmap {
        if (rect == null || previewWidth <= 0 || previewHeight <= 0) return bitmap
        val scale = max(
            previewWidth.toDouble() / bitmap.width,
            previewHeight.toDouble() / bitmap.height,
        )
        val displayedWidth = bitmap.width * scale
        val displayedHeight = bitmap.height * scale
        val offsetX = (displayedWidth - previewWidth) / 2.0
        val offsetY = (displayedHeight - previewHeight) / 2.0
        var left = (rect.x * previewWidth + offsetX) / scale
        var top = (rect.y * previewHeight + offsetY) / scale
        var width = rect.width * previewWidth / scale
        var height = rect.height * previewHeight / scale
        val horizontalMargin = width * 0.05
        val verticalMargin = height * 0.05
        left = max(0.0, left - horizontalMargin)
        top = max(0.0, top - verticalMargin)
        width = min(bitmap.width - left, width + horizontalMargin * 2)
        height = min(bitmap.height - top, height + verticalMargin * 2)
        val cropLeft = floor(left).toInt()
        val cropTop = floor(top).toInt()
        val cropWidth = min(bitmap.width - cropLeft, max(1, floor(width).toInt()))
        val cropHeight = min(bitmap.height - cropTop, max(1, floor(height).toInt()))
        return Bitmap.createBitmap(bitmap, cropLeft, cropTop, cropWidth, cropHeight)
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

/** Flutter 取景框相对于原生预览区域的归一化矩形。 */
private data class NormalizedRect(
    val x: Double,
    val y: Double,
    val width: Double,
    val height: Double,
)
