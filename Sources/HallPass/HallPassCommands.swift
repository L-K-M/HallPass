import AppKit
import SwiftUI
import HallPassCore

enum WorkspaceCommand {
    case add, edit, remove, review, load, discard, reset, preview
    case importBackup, exportBackup, backups, inspector, search, wifi, ethernet, help
}

@MainActor
struct WorkspaceActions {
    let model: HallPassModel
    let available: Bool
    let selectionCount: Int
    let tableFocused: Bool
    let showsInspector: Bool
    let interface: NetworkInterface
    let perform: (WorkspaceCommand) -> Void

    var canEdit: Bool { available && model.canEdit }
    var canEditSelection: Bool { canEdit && tableFocused && selectionCount == 1 }
    var canRemove: Bool { canEdit && tableFocused && selectionCount > 0 }
}

private struct WorkspaceActionsKey: FocusedValueKey {
    typealias Value = WorkspaceActions
}

extension FocusedValues {
    var hallPassActions: WorkspaceActions? {
        get { self[WorkspaceActionsKey.self] }
        set { self[WorkspaceActionsKey.self] = newValue }
    }
}

struct HallPassCommands: Commands {
    @FocusedValue(\.hallPassActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Netzbereich hinzufügen…") { actions?.perform(.add) }
                .keyboardShortcut("n").disabled(actions?.canEdit != true)
            Divider()
            Button("Konfiguration laden…") { actions?.perform(.load) }
                .keyboardShortcut("l").disabled(actions?.available != true)
            Button("Änderungen prüfen…") { actions?.perform(.review) }
                .keyboardShortcut("s").disabled(actions?.available != true || actions?.model.canReview != true)
            Button("Änderungen verwerfen…") { actions?.perform(.discard) }
                .disabled(actions?.canEdit != true || actions?.model.isDirty != true)
            Divider()
            Button("Backup importieren…") { actions?.perform(.importBackup) }
                .keyboardShortcut("o").disabled(actions?.canEdit != true)
            Button("Gespeicherten Zustand exportieren…") { actions?.perform(.exportBackup) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(actions?.available != true || actions?.model.isLoaded != true)
            Button("Backupordner öffnen") { actions?.perform(.backups) }
                .disabled(actions?.available != true || actions?.model.isDemo != false)
            Divider()
            Button("Alle Freigaben entfernen…") { actions?.perform(.reset) }
                .disabled(actions?.canEdit != true || actions?.model.draft == NetworkConfiguration())
        }

        CommandGroup(replacing: .saveItem) {
            Button("Schließen") {
                NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("w").disabled(NSApp.keyWindow == nil || actions?.model.busy == true)
        }

        CommandGroup(after: .pasteboard) {
            Button("IP-Bereich bearbeiten…") { actions?.perform(.edit) }
                .keyboardShortcut(.return, modifiers: .command).disabled(actions?.canEditSelection != true)
            Button("Entfernen") { actions?.perform(.remove) }
                .disabled(actions?.canRemove != true)
        }

        CommandGroup(after: .textEditing) {
            Button("IP-Bereiche suchen") { actions?.perform(.search) }
                .keyboardShortcut("f").disabled(actions?.available != true || actions?.model.isLoaded != true)
        }

        SidebarCommands()

        CommandGroup(after: .toolbar) {
            Toggle("Informationen", isOn: Binding(
                get: { actions?.showsInspector ?? false }, set: { _ in actions?.perform(.inspector) }
            ))
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(actions?.available != true || actions?.model.isLoaded != true)
            Divider()
            Toggle("WLAN", isOn: Binding(
                get: { actions?.interface == .wifi }, set: { _ in actions?.perform(.wifi) }
            ))
            .keyboardShortcut("1").disabled(actions?.available != true)
            Toggle("Ethernet", isOn: Binding(
                get: { actions?.interface == .ethernet }, set: { _ in actions?.perform(.ethernet) }
            ))
            .keyboardShortcut("2").disabled(actions?.available != true)
            Divider()
            Button(actions?.model.isDemo == true ? "Vorschau beenden…" : "Vorschau starten") { actions?.perform(.preview) }
                .disabled(actions?.available != true || (actions?.model.isLoaded == true && actions?.model.isDemo != true))
        }

        CommandGroup(replacing: .help) {
            Button("HallPass-Hilfe") { actions?.perform(.help) }.disabled(actions?.available != true)
            Link("Apple-Dokumentation zur Netzwerkfreigabe", destination: HallPassHelp.appleDocumentation)
        }
    }
}
