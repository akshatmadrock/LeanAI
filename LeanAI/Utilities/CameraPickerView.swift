import SwiftUI
import UIKit

/// UIViewControllerRepresentable wrapper for UIImagePickerController.
/// Used for both camera capture and photo library selection.
struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - UIImage helpers for Groq vision

extension UIImage {
    /// Resize and compress to JPEG for Groq vision API.
    /// Keeps the image under ~1MB which is well within Groq's 4MB limit.
    func compressedForVision(maxDimension: CGFloat = 1024, quality: CGFloat = 0.75) -> Data? {
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    /// Base64-encoded JPEG string ready for Groq's image_url field.
    var base64ForVision: String? {
        compressedForVision()?.base64EncodedString()
    }
}
