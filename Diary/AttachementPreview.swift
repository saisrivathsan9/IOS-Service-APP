//
//  AttachmentPreviewView.swift
//  Diary
//


import SwiftUI
import QuickLook

struct AttachmentPreviewView: View {
    let attachment: Attachment

    var body: some View {
        Group {
            if attachment.fileType == "image",
               let uiImage = UIImage(data: attachment.fileData) {
                // Image preview
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                // Document preview via QuickLook
                QuickLookPreview(attachment: attachment)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}


/// QuickLook wrapper that writes attachment bytes to a unique temp file,
/// exposes it to QLPreviewController, and removes the temp file when done.
struct QuickLookPreview: UIViewControllerRepresentable {
    let attachment: Attachment

    func makeCoordinator() -> Coordinator {
        Coordinator(attachment: attachment)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // nothing for now
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let attachment: Attachment
        var tempURL: URL?

        init(attachment: Attachment) {
            self.attachment = attachment
            super.init()

            // Create a unique temp filename to avoid collisions
            let tempDir = FileManager.default.temporaryDirectory
            let uniqueName = "\(UUID().uuidString)-\(attachment.fileName)"
            let url = tempDir.appendingPathComponent(uniqueName)

            do {
                try attachment.fileData.write(to: url, options: .atomic)
                self.tempURL = url
            } catch {
                // If writing fails, leave tempURL nil; QuickLook will show nothing.
                self.tempURL = nil
                NSLog("QuickLookPreview: failed to write temp file for \(attachment.fileName): \(error)")
            }
        }

        deinit {
            // Clean up the temporary file when the coordinator goes away
            if let url = tempURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return tempURL == nil ? 0 : 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            // Force unwrap is safe because numberOfPreviewItems returned 1
            return tempURL! as QLPreviewItem
        }
    }
}

