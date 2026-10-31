import AppKit
import UniformTypeIdentifiers

@MainActor
enum BackupPanels {
    static func open(in window: NSWindow, completion: @escaping @MainActor (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "HallPass-Backup importieren"
        panel.prompt = "Importieren"
        panel.message = "Das Backup ersetzt den Entwurf. Du kannst den Import widerrufen."
        panel.beginSheetModal(for: window) { response in
            MainActor.assumeIsolated { completion(response == .OK ? panel.url : nil) }
        }
    }

    static func save(in window: NSWindow, completion: @escaping @MainActor (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "HallPass-Backup.json"
        panel.title = "Gespeicherten Zustand exportieren"
        panel.prompt = "Exportieren"
        panel.message = "Enthält den zuletzt geladenen oder gespeicherten Zustand. Nicht übernommene Änderungen sind nicht enthalten."
        panel.beginSheetModal(for: window) { response in
            MainActor.assumeIsolated { completion(response == .OK ? panel.url : nil) }
        }
    }
}
