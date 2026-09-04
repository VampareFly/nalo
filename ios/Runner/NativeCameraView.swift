import AVFoundation
import Flutter
import UIKit

/// 注册使用 AVFoundation 的原生相机 Platform View。
final class NativeCameraPlugin {
    private static var permissionChannel: FlutterMethodChannel?

    static func register(with registrar: FlutterPluginRegistrar) {
        registrar.register(
            NativeCameraViewFactory(messenger: registrar.messenger()),
            withId: "nalo/native_camera_view"
        )
        let channel = FlutterMethodChannel(
            name: "nalo/native_camera_permission",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            guard call.method == "request" else {
                result(FlutterMethodNotImplemented)
                return
            }
            requestCameraPermission(result: result)
        }
        permissionChannel = channel
    }

    /// 直接使用 AVFoundation 返回系统相机权限，避免插件编译宏缓存导致状态错误。
    private static func requestCameraPermission(result: @escaping FlutterResult) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            result("granted")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    result(granted ? "granted" : "denied")
                }
            }
        case .denied:
            result("denied")
        case .restricted:
            result("restricted")
        @unknown default:
            result("denied")
        }
    }
}

/// 为 Flutter 创建独立的 AVFoundation 相机视图。
final class NativeCameraViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        NativeCameraView(frame: frame, viewId: viewId, messenger: messenger)
    }
}

private final class NativeCameraPreview: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

/// 使用后置摄像头管理 iOS 拍照会话，并将 Flutter 取景框映射到高清成片后裁剪输出。
private final class NativeCameraView: NSObject, FlutterPlatformView, AVCapturePhotoCaptureDelegate {
    private let previewView: NativeCameraPreview
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.sanjiang.nalo.native-camera")
    private let channel: FlutterMethodChannel
    private var pendingResult: FlutterResult?
    private var pendingCropRect: CGRect?
    private var pendingPreviewSize = CGSize.zero
    private var ready = false

    init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
        previewView = NativeCameraPreview(frame: frame)
        channel = FlutterMethodChannel(
            name: "nalo/native_camera_\(viewId)",
            binaryMessenger: messenger
        )
        super.init()
        // Platform View 在主线程创建，先绑定预览层再启动会话，避免主线程与 startRunning 竞争会话锁。
        previewView.previewLayer.session = session
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    func view() -> UIView {
        previewView
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isReady":
            result(ready)
        case "capture":
            capture(arguments: call.arguments, result: result)
        case "dispose":
            release()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = preferredBackCamera(),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        configureFocusAndExposure(device)
        session.commitConfiguration()
        session.startRunning()
        ready = true
    }

    private func preferredBackCamera() -> AVCaptureDevice? {
        if #available(iOS 13.0, *) {
            return AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private func configureFocusAndExposure(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            let center = CGPoint(x: 0.5, y: 0.5)
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = center
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = center
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            // 不支持特定参数时保留 AVFoundation 默认行为。
        }
    }

    /// 保存本次 Flutter 取景框和预览尺寸，供照片回调映射到成片像素坐标。
    private func capture(arguments: Any?, result: @escaping FlutterResult) {
        let cropRect = normalizedCropRect(arguments)
        let previewSize = previewView.bounds.size
        sessionQueue.async { [weak self] in
            guard let self, ready, pendingResult == nil else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "camera_not_ready", message: "Native camera is not ready.", details: nil))
                }
                return
            }
            pendingResult = result
            pendingCropRect = cropRect
            pendingPreviewSize = previewSize
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let result = pendingResult
        pendingResult = nil
        let cropRect = pendingCropRect
        pendingCropRect = nil
        let previewSize = pendingPreviewSize
        pendingPreviewSize = .zero
        if let error {
            DispatchQueue.main.async {
                result?(FlutterError(code: "capture_failed", message: error.localizedDescription, details: nil))
            }
            return
        }
        guard let sourceData = photo.fileDataRepresentation(),
              let data = optimizedPhotoData(
                sourceData,
                cropRect: cropRect,
                previewSize: previewSize
              ) else {
            DispatchQueue.main.async {
                result?(FlutterError(code: "capture_failed", message: "Photo data is unavailable.", details: nil))
            }
            return
        }
        let debugId = UUID().uuidString
        #if DEBUG
        saveDebugPhotoPair(original: sourceData, upload: data, id: debugId)
        #endif
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nalo_upload_\(debugId).jpg")
        do {
            try data.write(to: url, options: .atomic)
            DispatchQueue.main.async {
                result?(url.path)
            }
        } catch {
            DispatchQueue.main.async {
                result?(FlutterError(code: "capture_failed", message: error.localizedDescription, details: nil))
            }
        }
    }

    /// 将系统高清成片映射到取景框、裁剪安全边距，再缩放压缩供预览和上传。
    private func optimizedPhotoData(
        _ data: Data,
        cropRect: CGRect?,
        previewSize: CGSize
    ) -> Data? {
        guard let sourceImage = UIImage(data: data) else { return nil }
        let normalizedImage = normalizeOrientation(sourceImage)
        let image = cropToPreviewFrame(
            normalizedImage,
            normalizedRect: cropRect,
            previewSize: previewSize
        )
        let maxPixel: CGFloat = 2500
        let longestSide = max(image.size.width, image.size.height)
        let targetImage: UIImage
        if longestSide > maxPixel {
            let ratio = maxPixel / longestSide
            let targetSize = CGSize(
                width: image.size.width * ratio,
                height: image.size.height * ratio
            )
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = true
            targetImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            targetImage = image
        }

        let maxBytes = 5 * 1024 * 1024
        var quality: CGFloat = 0.88
        var output = targetImage.jpegData(compressionQuality: quality)
        while let current = output, current.count > maxBytes, quality > 0.60 {
            quality = max(0.60, quality - 0.08)
            output = targetImage.jpegData(compressionQuality: quality)
        }
        return output
    }

    /// 解析 Flutter 传入的取景框归一化坐标；缺失时保留完整照片。
    private func normalizedCropRect(_ arguments: Any?) -> CGRect? {
        guard let values = arguments as? [String: Any],
              let x = values["x"] as? NSNumber,
              let y = values["y"] as? NSNumber,
              let width = values["width"] as? NSNumber,
              let height = values["height"] as? NSNumber,
              width.doubleValue > 0,
              height.doubleValue > 0 else {
            return nil
        }
        return CGRect(
            x: x.doubleValue,
            y: y.doubleValue,
            width: width.doubleValue,
            height: height.doubleValue
        )
    }

    /// 将带 EXIF 方向的 UIImage 绘制为方向固定的像素图，便于准确裁剪。
    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// 按 resizeAspectFill 的显示关系映射到照片，并保留 12% 边距避免切边。
    private func cropToPreviewFrame(
        _ image: UIImage,
        normalizedRect: CGRect?,
        previewSize: CGSize
    ) -> UIImage {
        guard let normalizedRect,
              previewSize.width > 0,
              previewSize.height > 0,
              let cgImage = image.cgImage else {
            return image
        }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = max(
            previewSize.width / imageSize.width,
            previewSize.height / imageSize.height
        )
        let displayedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let offset = CGPoint(
            x: (displayedSize.width - previewSize.width) / 2,
            y: (displayedSize.height - previewSize.height) / 2
        )
        var crop = CGRect(
            x: (normalizedRect.minX * previewSize.width + offset.x) / scale,
            y: (normalizedRect.minY * previewSize.height + offset.y) / scale,
            width: normalizedRect.width * previewSize.width / scale,
            height: normalizedRect.height * previewSize.height / scale
        )
        crop = crop.insetBy(dx: -crop.width * 0.12, dy: -crop.height * 0.12)
        crop = crop.integral.intersection(CGRect(origin: .zero, size: imageSize))
        guard crop.width > 0,
              crop.height > 0,
              let cropped = cgImage.cropping(to: crop) else {
            return image
        }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    #if DEBUG
    /// Debug 构建保留原始成片和实际上传图，便于对比压缩前后的识别细节。
    private func saveDebugPhotoPair(original: Data, upload: Data, id: String) {
        guard let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return }
        try? original.write(
            to: directory.appendingPathComponent("nalo_original_\(id).jpg"),
            options: .atomic
        )
        try? upload.write(
            to: directory.appendingPathComponent("nalo_upload_\(id).jpg"),
            options: .atomic
        )
    }
    #endif

    private func release() {
        ready = false
        let cameraSession = session
        sessionQueue.async {
            if cameraSession.isRunning {
                cameraSession.stopRunning()
            }
        }
    }

    deinit {
        channel.setMethodCallHandler(nil)
        release()
    }
}
