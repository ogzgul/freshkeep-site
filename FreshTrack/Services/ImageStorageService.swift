import UIKit

enum ImageStorageService {

    private static var imagesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ProductImages")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func newFileName() -> String { UUID().uuidString + ".jpg" }

    static func save(_ image: UIImage, fileName: String) {
        let url = imagesDirectory.appendingPathComponent(fileName)
        if let data = image.jpegData(compressionQuality: 0.82) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func load(fileName: String) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    static func delete(fileName: String) {
        let url = imagesDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - UIImage thumbnail helper

extension UIImage {
    func thumbnailed(maxSize: CGFloat = 600) -> UIImage {
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        guard scale < 1.0 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
