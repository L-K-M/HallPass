import SwiftUI

@main
struct HallPassApp: App {
    @State private var model = HallPassModel(mode: CommandLine.arguments.contains("--demo") ? .preview : .system)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // One machine-wide configuration has one draft, rather than competing windows.
        Window("HallPass", id: "main") {
            ContentView(model: model)
        }
        .defaultSize(width: 980, height: 640)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .commands { HallPassCommands() }
    }
}
