import SwiftUI
import AVFoundation
import AudioToolbox

/// 全屏扫码容器：右上角关闭按钮。
struct ScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CameraScannerView(onScan: onScan).ignoresSafeArea()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding()
                    .shadow(radius: 4)
            }
        }
    }
}

/// 用 AVCaptureVideoPreviewLayer 作为 backing layer 的视图，随视图自动缩放。
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

/// AVFoundation 二维码扫描（离线）。
struct CameraScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            context.coordinator.show(message: "请在设置中允许访问摄像头", on: vc)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        context.coordinator.setupSession(on: vc)
                    } else {
                        context.coordinator.show(message: "未授权访问摄像头", on: vc)
                    }
                }
            }
        default:
            context.coordinator.setupSession(on: vc)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        var session: AVCaptureSession?
        var handled = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func setupSession(on vc: UIViewController) {
            guard session == nil else { return }
            let session = AVCaptureSession()
            self.session = session
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video)
            guard let camera = camera,
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                show(message: "无法访问摄像头", on: vc)
                return
            }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.qr]
            }

            let previewView = PreviewView(frame: vc.view.bounds)
            previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            previewView.videoPreviewLayer.session = session
            previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
            vc.view.addSubview(previewView)

            DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        }

        func stop() {
            session?.stopRunning()
        }

        func show(message: String, on vc: UIViewController) {
            let label = UILabel()
            label.text = message
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 0
            label.frame = vc.view.bounds.insetBy(dx: 20, dy: 20)
            vc.view.addSubview(label)
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !handled,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            handled = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onScan(value)
        }
    }
}
