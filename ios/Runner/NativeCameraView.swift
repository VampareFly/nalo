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

/// 使用虚拟后置摄像头和质量优先照片输出管理 iOS 拍照会话。
private final class NativeCameraView: NSObject, FlutterPlatformView, AVCapturePhotoCaptureDelegate {
    private let previewView: NativeCameraPreview
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.sanjiang.nalo.native-camera")
    private let channel: FlutterMethodChannel
    private var pendingResult: FlutterResult?
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
            capture(result: result)
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

    private func capture(result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self, ready, pendingResult == nil else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "camera_not_ready", message: "Native camera is not ready.", details: nil))
                }
                return
            }
            pendingResult = result
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
        if let error {
            DispatchQueue.main.async {
                result?(FlutterError(code: "capture_failed", message: error.localizedDescription, details: nil))
            }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async {
                result?(FlutterError(code: "capture_failed", message: "Photo data is unavailable.", details: nil))
            }
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nalo_test_\(UUID().uuidString).jpg")
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
