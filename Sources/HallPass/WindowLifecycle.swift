import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        return !WindowLifecycle.shared.showWindow()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let lifecycle = WindowLifecycle.shared
        guard let model = lifecycle.model else { return .terminateNow }
        guard !model.busy else {
            lifecycle.explainBusy()
            return .terminateCancel
        }
        guard let window = lifecycle.window else { return .terminateNow }
        guard window.attachedSheet == nil else { return .terminateCancel }
        guard model.isDirty else { return .terminateNow }

        lifecycle.confirmDiscard(in: window) { discard in
            sender.reply(toApplicationShouldTerminate: discard)
        }
        return .terminateLater
    }
}

@MainActor
final class WindowLifecycle {
    static let shared = WindowLifecycle()
    fileprivate weak var model: HallPassModel?
    fileprivate var window: NSWindow?
    private var confirming = false

    private init() { }

    func showWindow() -> Bool {
        guard let window else { return false }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        return true
    }

    func explainBusy() {
        model?.error = "HallPass arbeitet noch. Schließe zuerst den Administrator-Dialog und warte, bis der Vorgang abgeschlossen ist."
        window?.makeKeyAndOrderFront(nil)
    }

    func confirmDiscard(in window: NSWindow, completion: @escaping @MainActor (Bool) -> Void) {
        guard !confirming, let model else { completion(false); return }
        confirming = true
        let alert = NSAlert()
        alert.messageText = "Nicht übernommene Änderungen verwerfen?"
        alert.informativeText = "Deine Änderungen wurden noch nicht in macOS gespeichert. Wähle „Weiter bearbeiten“, um sie zuerst zu prüfen und zu übernehmen."
        alert.addButton(withTitle: "Weiter bearbeiten").keyEquivalent = "\r"
        alert.addButton(withTitle: "Verwerfen").hasDestructiveAction = true
        alert.beginSheetModal(for: window) { response in
            MainActor.assumeIsolated {
                self.confirming = false
                guard response == .alertSecondButtonReturn else { completion(false); return }
                completion(model.discardForClosing())
            }
        }
    }
}

struct WindowConnection: NSViewRepresentable {
    let model: HallPassModel
    let connected: (NSWindow) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(model: model, connected: connected) }

    func makeNSView(context: Context) -> ConnectionView {
        let view = ConnectionView()
        view.connect = { [weak coordinator = context.coordinator] window in
            // Let SwiftUI finish installing the window before interposing its delegate.
            DispatchQueue.main.async { coordinator?.connect(to: window) }
        }
        return view
    }

    func updateNSView(_ nsView: ConnectionView, context: Context) {
        guard let window = nsView.window, window.isDocumentEdited != model.isDirty else { return }
        window.isDocumentEdited = model.isDirty
    }

    final class ConnectionView: NSView {
        var connect: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { connect?(window) }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private let model: HallPassModel
        private let connected: (NSWindow) -> Void
        // Objective-C introspection only reads this weak reference; connection stays on the main actor.
        nonisolated(unsafe) private weak var originalDelegate: (any NSWindowDelegate)?
        private weak var window: NSWindow?
        private var mouseMonitor: Any?

        init(model: HallPassModel, connected: @escaping (NSWindow) -> Void) {
            self.model = model
            self.connected = connected
        }

        func connect(to window: NSWindow) {
            guard self.window !== window else { return }
            self.window = window
            originalDelegate = window.delegate
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.tabbingMode = .disallowed
            WindowLifecycle.shared.model = model
            WindowLifecycle.shared.window = window
            DispatchQueue.main.async { self.connected(window) }
            if CommandLine.arguments.contains("--diagnose-clicks") {
                mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
                    guard let window = event.window, let content = window.contentView else { return event }
                    let point = content.convert(event.locationInWindow, from: nil)
                    let hit = content.hitTest(point)
                    let message = "Mouse event: number=\(window.windowNumber) window=\(event.locationInWindow) content=\(point) hit=\(String(describing: hit))\n"
                    FileHandle.standardOutput.write(Data(message.utf8))
                    var view = hit
                    while let current = view {
                        if let table = current as? NSTableView {
                            let tablePoint = table.convert(event.locationInWindow, from: nil)
                            FileHandle.standardOutput.write(Data("Native table point: \(tablePoint), row=\(table.row(at: tablePoint)), frame=\(table.frame)\n".utf8))
                            DispatchQueue.main.async {
                                FileHandle.standardOutput.write(Data("Native selected rows: \(table.selectedRowIndexes)\n".utf8))
                            }
                            break
                        }
                        view = current.superview
                    }
                    return event
                }
            }
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard !model.busy else { WindowLifecycle.shared.explainBusy(); return false }
            guard sender.attachedSheet == nil else { return false }
            guard model.isDirty else { return originalDelegate?.windowShouldClose?(sender) ?? true }
            WindowLifecycle.shared.confirmDiscard(in: sender) { discard in
                if discard { sender.performClose(nil) }
            }
            return false
        }

        func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
            model.canEdit ? model.undoManager : nil
        }

        // SwiftUI owns other window delegate behavior, including restoration and fullscreen.
        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || originalDelegate?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            if originalDelegate?.responds(to: selector) == true { return originalDelegate }
            return super.forwardingTarget(for: selector)
        }
    }
}
