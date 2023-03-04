//
//  FileOpener.swift
//
//
//  Created by Kamaal M Farah on 26/02/2023.
//

import SwiftUI
import UniformTypeIdentifiers

public enum FileOpenerErrors: Error {
    case fileNotFound
    case fileCouldNotBeRead(context: Error)
    case notAllowedToReadFile
}

extension View {
    public func openFile(
        isPresented: Binding<Bool>,
        contentTypes: [UTType] = [.content],
        onFileOpen: @escaping (_ content: Result<Data?, FileOpenerErrors>) -> Void) -> some View {
            self
                .modifier(OpenFileViewModifier(
                    isPresented: isPresented,
                    contentTypes: contentTypes,
                    onFileOpen: onFileOpen))
        }
}

private struct OpenFileViewModifier: ViewModifier {
    @Binding var isPresented: Bool

    let contentTypes: [UTType]
    let onFileOpen: (_ content: Result<Data?, FileOpenerErrors>) -> Void

    init(
        isPresented: Binding<Bool>,
        contentTypes: [UTType],
        onFileOpen: @escaping (_ content: Result<Data?, FileOpenerErrors>) -> Void) {
            self._isPresented = isPresented
            self.contentTypes = contentTypes
            self.onFileOpen = onFileOpen
        }

    func body(content: Content) -> some View {
        content
            #if canImport(UIKit)
            .sheet(isPresented: $isPresented, content: {
                DocumentPickerView(isPresented: $isPresented, contentTypes: contentTypes, onFileOpen: onFileOpen)
            })
            #else
            .onChange(of: isPresented, perform: { newValue in
                guard newValue else { return }

                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.allowedContentTypes = contentTypes

                let status = panel.runModal()
                if status != .OK {
                    switch status {
                    case .abort, .continue, .stop, .cancel:
                        break
                    default:
                        assertionFailure("unknown status")
                    }
                    onFileOpen(.success(.none))
                    isPresented = false
                    return
                }

                guard let url = panel.url else {
                    onFileOpen(.failure(.fileNotFound))
                    isPresented = false
                    return
                }

                onFileOpen(SecureFileOpener.readData(from: url).map({ $0 as Data? }))
                isPresented = false
            })
            #endif
    }
}

#if canImport(UIKit)
private struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    let contentTypes: [UTType]
    let onFileOpen: (_ content: Result<Data?, FileOpenerErrors>) -> Void

    init(
        isPresented: Binding<Bool>,
        contentTypes: [UTType],
        onFileOpen: @escaping (_ content: Result<Data?, FileOpenerErrors>) -> Void) {
            self._isPresented = isPresented
            self.contentTypes = contentTypes
            self.onFileOpen = onFileOpen
        }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = false
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.onFileOpen(.failure(.fileNotFound))
                parent.isPresented = false
                return
            }

            parent.onFileOpen(SecureFileOpener.readData(from: url).map({ $0 as Data? }))
            parent.isPresented = false
        }
    }
}
#endif

private struct SecureFileOpener {
    private init() { }

    static func readData(from url: URL) -> Result<Data, FileOpenerErrors> {
        guard url.startAccessingSecurityScopedResource() else {
            return .failure(.notAllowedToReadFile)
        }

        let content: Data
        do {
            content = try Data(contentsOf: url)
        } catch {
            return .failure(.fileCouldNotBeRead(context: error))
        }

        url.stopAccessingSecurityScopedResource()
        return .success(content)
    }
}
