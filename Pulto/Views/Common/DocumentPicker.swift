//
//  DocumentPicker.swift
//  Pulto
//
//  Cross-platform document picker for file selection
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit

struct DocumentPickerViewController: UIViewControllerRepresentable {
    let onDocumentsPicked: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .commaSeparatedText,
            .tabSeparatedText,
            .json,
            .plainText,
            .data,
            UTType(filenameExtension: "csv") ?? .plainText,
            UTType(filenameExtension: "tsv") ?? .plainText
        ])
        
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .formSheet
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerViewController
        
        init(_ parent: DocumentPickerViewController) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onDocumentsPicked(urls)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("Document picker was cancelled")
        }
    }
}
#endif

#if os(macOS)
import AppKit

struct DocumentPickerViewController: NSViewControllerRepresentable {
    let onDocumentsPicked: ([URL]) -> Void
    
    func makeNSViewController(context: Context) -> NSViewController {
        let controller = DocumentPickerNSViewController()
        controller.onDocumentsPicked = onDocumentsPicked
        return controller
    }
    
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        // No updates needed
    }
}

class DocumentPickerNSViewController: NSViewController {
    var onDocumentsPicked: (([URL]) -> Void)?
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .commaSeparatedText,
            .tabSeparatedText,
            .json,
            .plainText,
            .data
        ]
        
        panel.begin { response in
            if response == .OK {
                self.onDocumentsPicked?(panel.urls)
            }
        }
    }
}
#endif

// MARK: - SwiftUI Wrapper

struct DocumentPickerView: View {
    let onDocumentsPicked: ([URL]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        DocumentPickerViewController { urls in
            onDocumentsPicked(urls)
            dismiss()
        }
    }
}
