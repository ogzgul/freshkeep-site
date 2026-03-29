import SwiftUI
import PhotosUI

// MARK: - Reusable image picker used in Add / Edit forms

struct ProductImagePickerView: View {
    @Binding var image: UIImage?
    var onChanged: () -> Void = {}

    @State private var showOptions = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 12) {
            // Photo well
            Button { showOptions = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(width: 90, height: 90)

                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text("Add Photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            // Action buttons shown when image exists
            if image != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        showOptions = true
                    } label: {
                        Label("Change Photo", systemImage: "photo.on.rectangle")
                            .font(.subheadline)
                    }
                    Button(role: .destructive) {
                        image = nil
                        onChanged()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.subheadline)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("Product Photo", isPresented: $showOptions) {
            Button("Choose from Library") { showPhotoPicker = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            if image != nil {
                Button("Remove Photo", role: .destructive) {
                    image = nil
                    onChanged()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images)
        .sheet(isPresented: $showCamera) {
            CameraPickerView { picked in
                image = picked.thumbnailed()
                onChanged()
            }
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { return }
                await MainActor.run {
                    image = uiImage.thumbnailed()
                    onChanged()
                }
            }
        }
    }
}

// MARK: - Camera wrapper

struct CameraPickerView: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let img = info[.originalImage] as? UIImage {
                parent.onPick(img)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Row thumbnail (used in ProductRowView)

struct ProductThumbnailView: View {
    let fileName: String?
    let fallbackIcon: String

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                Text(fallbackIcon)
                    .font(.title2)
                    .frame(width: 38)
            }
        }
        .task(id: fileName) {
            guard let fn = fileName else { image = nil; return }
            image = ImageStorageService.load(fileName: fn)
        }
    }
}
