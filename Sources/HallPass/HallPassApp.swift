import SwiftUI
import AppKit

@main
struct HallPassApp: App {
    @State private var model = HallPassModel(demo: CommandLine.arguments.contains("--demo"))
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("HallPass", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 760, minHeight: 500)
                .task { model.restoreRestartState() }
        }
        .defaultSize(width: 860, height: 600)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button("Apple-Dokumentation öffnen") {
                    NSWorkspace.shared.open(URL(string: "https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy")!)
                }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return AppCloseGuard.shared.mayClose() ? .terminateNow : .terminateCancel
    }
}

@MainActor
final class AppCloseGuard: NSObject, NSWindowDelegate {
    static let shared = AppCloseGuard()
    weak var model: HallPassModel?

    func mayClose() -> Bool {
        guard let model else { return true }
        if model.busy {
            let alert = NSAlert()
            alert.messageText = "HallPass arbeitet noch"
            alert.informativeText = "Schließe zuerst den Administrator-Dialog und warte, bis der Vorgang abgeschlossen ist."
            alert.runModal()
            return false
        }
        guard model.isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Ungespeicherte Änderungen verwerfen?"
        alert.informativeText = "Deine Änderungen an den Netzfreigaben wurden noch nicht übernommen."
        alert.addButton(withTitle: "Weiter bearbeiten")
        alert.addButton(withTitle: "Verwerfen")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { mayClose() }
}

struct WindowAccessor: NSViewRepresentable {
    let model: HallPassModel
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            AppCloseGuard.shared.model = model
            view.window?.delegate = AppCloseGuard.shared
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { }
}
