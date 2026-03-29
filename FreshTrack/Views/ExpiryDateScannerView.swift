import SwiftUI
import AVFoundation
import Vision
import AudioToolbox

// MARK: - Sheet

struct ExpiryDateScannerSheet: View {
    @Binding var isPresented: Bool
    var onDateDetected: (Date) -> Void

    @State private var isActive = true
    @State private var cameraAuthorized: Bool? = nil
    @State private var detectedDates: [Date] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraAuthorized == true {
                ExpiryDateCameraView(isActive: $isActive) { text in
                    let found = ExpiryDateParser.parse(from: text)
                    if !found.isEmpty {
                        DispatchQueue.main.async { detectedDates = found }
                    }
                }
                .ignoresSafeArea()

                VStack {
                    // Close button
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

                    // Scan frame
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(detectedDates.isEmpty ? Color.white : Color.teal, lineWidth: 2)
                        .frame(width: 300, height: 90)
                        .animation(.easeInOut(duration: 0.3), value: detectedDates.isEmpty)

                    Text(detectedDates.isEmpty
                         ? "Kamerayı son kullanma tarihine doğrultun"
                         : "Tarih bulundu! Doğru olanı seçin:")
                        .foregroundStyle(.white)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .shadow(radius: 4)

                    // Detected date buttons
                    if !detectedDates.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(detectedDates, id: \.self) { date in
                                Button {
                                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                                    onDateDetected(date)
                                    isPresented = false
                                } label: {
                                    Text(date.formatted(.dateTime.day().month(.wide).year()))
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 28)
                                        .padding(.vertical, 12)
                                        .background(.teal, in: RoundedRectangle(cornerRadius: 12))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(.top, 12)
                    }

                    Spacer().frame(height: 60)
                }

            } else if cameraAuthorized == false {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary)

                    Text("Camera Access Required")
                        .font(.title3).fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text("Please allow camera access in\nSettings to scan expiry dates.")
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

// MARK: - Camera view with continuous OCR

struct ExpiryDateCameraView: UIViewRepresentable {
    @Binding var isActive: Bool
    var onTextDetected: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextDetected: onTextDetected, isActive: $isActive)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.setupSession(in: view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if isActive {
            DispatchQueue.global(qos: .userInitiated).async {
                if !context.coordinator.session.isRunning {
                    context.coordinator.session.startRunning()
                }
            }
        } else {
            context.coordinator.session.stopRunning()
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let session = AVCaptureSession()
        let onTextDetected: (String) -> Void
        @Binding var isActive: Bool
        private var lastProcessTime = Date.distantPast
        private let processingInterval: TimeInterval = 0.7

        init(onTextDetected: @escaping (String) -> Void, isActive: Binding<Bool>) {
            self.onTextDetected = onTextDetected
            self._isActive = isActive
        }

        func setupSession(in view: PreviewView) {
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(
                self,
                queue: DispatchQueue(label: "expiry.ocr.queue", qos: .userInitiated)
            )
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return
            }
            session.addOutput(output)
            session.commitConfiguration()

            // Continuous autofocus for close-up text
            if device.isFocusModeSupported(.continuousAutoFocus),
               (try? device.lockForConfiguration()) != nil {
                device.focusMode = .continuousAutoFocus
                device.unlockForConfiguration()
            }

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            view.previewLayer = layer
            view.layer.addSublayer(layer)

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }

        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            let now = Date()
            guard now.timeIntervalSince(lastProcessTime) >= processingInterval else { return }
            lastProcessTime = now

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let request = VNRecognizeTextRequest { [weak self] req, _ in
                guard let obs = req.results as? [VNRecognizedTextObservation] else { return }
                let text = obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                if !text.isEmpty { self?.onTextDetected(text) }
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["tr-TR", "en-US"]
            request.usesLanguageCorrection = false

            try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
        }
    }

    // MARK: Preview View

    final class PreviewView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                guard let layer = previewLayer else { return }
                self.layer.addSublayer(layer)
                setNeedsLayout()
            }
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}

// MARK: - Date Parser

enum ExpiryDateParser {
    static func parse(from text: String) -> [Date] {
        let lowered = text.lowercased()
        let lines = lowered.components(separatedBy: .newlines)

        // Keywords that appear near expiry dates
        let keywords = ["skt", "son kul", "best before", "exp ", "expiry", "use by",
                        "bb ", "tüketim", "kullanma tarihi", "tarix", "срок"]

        // Prefer lines that contain a keyword (+ the line after)
        var searchText = lowered
        var prioritized: [String] = []
        for (i, line) in lines.enumerated() {
            if keywords.contains(where: { line.contains($0) }) {
                prioritized.append(line)
                if i + 1 < lines.count { prioritized.append(lines[i + 1]) }
            }
        }
        if !prioritized.isEmpty {
            searchText = prioritized.joined(separator: " ")
        }

        var dates: [Date] = []

        // DD/MM/YYYY  or  DD.MM.YYYY  or  DD-MM-YYYY  or  DD MM YYYY
        dates += match(#"(\d{1,2})[/\.\- ](\d{1,2})[/\.\- ](20\d{2})"#, in: searchText) { g in
            makeDate(day: Int(g[0]), month: Int(g[1]), year: Int(g[2]))
        }
        // MM/YYYY  or  MM.YYYY  or  MM YYYY
        dates += match(#"(\d{1,2})[/\. ](20\d{2})"#, in: searchText) { g in
            makeLastDay(month: Int(g[0]), year: Int(g[1]))
        }
        // DD/MM/YY  or  DD.MM.YY  or  DD MM YY
        dates += match(#"(\d{1,2})[/\.\- ](\d{1,2})[/\.\- ](\d{2})\b"#, in: searchText) { g in
            guard let y2 = Int(g[2]) else { return nil }
            return makeDate(day: Int(g[0]), month: Int(g[1]), year: y2 + 2000)
        }
        // MM/YY  or  MM.YY  or  MM YY
        dates += match(#"(\d{1,2})[/\. ](\d{2})\b"#, in: searchText) { g in
            guard let m = Int(g[0]), m >= 1, m <= 12, let y2 = Int(g[1]) else { return nil }
            return makeLastDay(month: m, year: y2 + 2000)
        }

        let now = Date()
        let unique = Array(Set(dates)).filter { $0 > now }.sorted()
        return Array(unique.prefix(3))
    }

    // MARK: Helpers

    private static func match(
        _ pattern: String,
        in text: String,
        transform: ([String]) -> Date?
    ) -> [Date] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex
            .matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { m -> Date? in
                let groups = (1..<m.numberOfRanges).map { i -> String in
                    let r = m.range(at: i)
                    return r.location != NSNotFound ? ns.substring(with: r) : ""
                }
                return transform(groups)
            }
    }

    private static func makeDate(day: Int?, month: Int?, year: Int?) -> Date? {
        guard let d = day, let m = month, let y = year,
              d >= 1, d <= 31, m >= 1, m <= 12, y >= 2020 else { return nil }
        return Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
    }

    private static func makeLastDay(month: Int?, year: Int?) -> Date? {
        guard let m = month, let y = year,
              m >= 1, m <= 12, y >= 2020 else { return nil }
        // day=0 of the next month = last day of this month
        return Calendar.current.date(from: DateComponents(year: y, month: m + 1, day: 0))
    }
}
