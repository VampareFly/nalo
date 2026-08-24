package com.sanjiang.nalo

import android.content.Context
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
                    result.success(file.absolutePath)
                }

                override fun onError(exception: ImageCaptureException) {
                    result.error("capture_failed", exception.message, null)
                }
            },
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
        channel.setMethodCallHandler(null)
    }
}
