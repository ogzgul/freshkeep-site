import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewRepresentable {
    var onScan: (String) -> Void
    @Binding var isActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, isActive: $isActive)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.setupSession(in: view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if isActive {
            DispatchQueue.global(qos: .userInitiated).async {
                context.coordinator.session.startRunning()
            }
        } else {
            context.coordinator.session.stopRunning()
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let session = AVCaptureSession()
        let onScan: (String) -> Void
        @Binding var isActive: Bool
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void, isActive: Binding<Bool>) {
            self.onScan = onScan
            self._isActive = isActive
        }

        func setupSession(in view: PreviewView) {
            session.beginConfiguration()

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [
                .ean8, .ean13, .upce, .code128, .code39, .qr
            ]

            session.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            view.previewLayer = layer
            view.layer.addSublayer(layer)

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput objects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasScanned,
                  let obj = objects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            hasScanned = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            isActive = false
            onScan(value)
        }
    }

    // MARK: - Preview View

    final class PreviewView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                if let layer = previewLayer {
                    self.layer.addSublayer(layer)
                    setNeedsLayout()
                }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}

// MARK: - Full-screen scanner sheet

struct BarcodeScannerSheet: View {
    @Binding var isPresented: Bool
    var onScan: (String) -> Void

    @State private var isActive = true
    @State private var cameraAuthorized: Bool? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraAuthorized == true {
                BarcodeScannerView(onScan: { code in
                    onScan(code)
                    isPresented = false
                }, isActive: $isActive)
                .ignoresSafeArea()

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            isActive = false
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }
                        .padding()
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 260, height: 160)
                        .padding(.bottom, 80)

                    Text("Point camera at barcode")
                        .foregroundStyle(.white)
                        .font(.subheadline)
                        .padding(.bottom, 40)
                        .shadow(radius: 4)
                }
            } else if cameraAuthorized == false {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary)

                    Text("Camera Access Required")
                        .font(.title3).fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text("Please allow camera access in\nSettings to scan barcodes.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 28).padding(.vertical, 12)
                            .background(.teal, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }

                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(32)
            }
        }
        .onAppear { checkCameraPermission() }
        .onDisappear { isActive = false }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAuthorized = true
        case .denied, .restricted:
            cameraAuthorized = false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { cameraAuthorized = granted }
            }
        @unknown default:
            cameraAuthorized = false
        }
    }
}
