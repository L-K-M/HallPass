import AppKit
import SwiftUI
import HallPassCore

struct NetworkRow: Identifiable {
    enum Status: String {
        case saved = "Gespeichert"
        case added = "Hinzugefügt"
        case invalid = "Ungültiger Wert"

        var symbol: String {
            switch self {
            case .saved: "checkmark"
            case .added: "plus.circle"
            case .invalid: "exclamationmark.triangle"
            }
        }
    }

    let id: Int
    let notation: String
    let status: Status
    var cidr: CIDR? { try? CIDR(notation) }
    var version: String { cidr.map { $0.isIPv6 ? "IPv6" : "IPv4" } ?? "–" }
}

struct ContentView: View {
    private static let minimumDetailWidth: CGFloat = 430

    @Bindable var model: HallPassModel
    @Environment(\.undoManager) private var windowUndoManager
    @SceneStorage("selectedInterface") private var interfaceName = NetworkInterface.wifi.rawValue
    @SceneStorage("showsInspector") private var showsInspector = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selection = Set<Int>()
    @State private var searchText = ""
    @State private var sheet: WorkspaceSheet?
    @State private var confirmation: DraftConfirmation?
    @State private var showingFilePanel = false
    @State private var window: NSWindow?
    @FocusState private var searchFocused: Bool

    private var interface: NetworkInterface { NetworkInterface(rawValue: interfaceName) ?? .wifi }
    private var available: Bool { !model.busy && sheet == nil && confirmation == nil && !showingFilePanel }

    private var rows: [NetworkRow] {
        var saved = (model.snapshot?.configuration[interface] ?? [])
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return (model.draft[interface] ?? []).enumerated().map { index, notation in
            let wasSaved = saved[notation, default: 0] > 0
            saved[notation, default: 0] -= 1
            let status: NetworkRow.Status = (try? CIDR(notation)) == nil ? .invalid : (wasSaved ? .saved : .added)
            return NetworkRow(id: index, notation: notation, status: status)
        }
    }

    private var visibleRows: [NetworkRow] {
        guard !searchText.isEmpty else { return rows }
        return rows.filter { $0.notation.localizedStandardContains(searchText) || $0.version.localizedStandardContains(searchText) }
    }

    private var selectedRows: [NetworkRow] { visibleRows.filter { selection.contains($0.id) } }

    private var windowContents: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 280)
        } detail: {
            detail
                .navigationSplitViewColumnWidth(min: Self.minimumDetailWidth, ideal: 520)
                .navigationTitle("HallPass")
                .navigationSubtitle(interface.title)
                .toolbar { toolbar }
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: $showsInspector) {
            NetworkInspector(rows: selectedRows, interface: interface, canEdit: model.canEdit && available) {
                perform(.edit)
            }
            .inspectorColumnWidth(min: NetworkInspector.minimumWidth, ideal: NetworkInspector.idealWidth, max: NetworkInspector.maximumWidth)
        }
        .focusedSceneValue(\.hallPassActions, WorkspaceActions(
            model: model, available: available, selectionCount: selectedRows.count,
            selectionIsActive: !searchFocused, showsInspector: showsInspector, interface: interface, perform: perform
        ))
    }

    var body: some View {
        windowContents
        .background(WindowConnection(model: model) { window = $0 }.frame(width: 0, height: 0))
        .task { model.restoreSession() }
        .onChange(of: windowUndoManager, initial: true) { model.useUndoManager(windowUndoManager) }
        .sheet(item: $sheet) { request in
            switch request {
            case .add:
                NetworkEditor(model: model, interface: interface)
            case .edit(let row):
                NetworkEditor(model: model, interface: interface, entry: row)
            case .review:
                ReviewView(model: model)
            case .help:
                HelpView()
            }
        }
        .alert("Vorgang nicht abgeschlossen", isPresented: Binding(
            get: { model.error != nil }, set: { if !$0 { model.error = nil } }
        )) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
        .alert(confirmation?.title ?? "", isPresented: Binding(
            get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }
        ), presenting: confirmation) { pending in
            Button(pending.actionTitle, role: .destructive) { confirm(pending) }
            Button("Abbrechen", role: .cancel) { }
        } message: { pending in
            Text(pending.message)
        }
        .onChange(of: model.draft) { selection.removeAll() }
        .onChange(of: interfaceName) { selection.removeAll() }
        .onChange(of: searchText) { selection.formIntersection(Set(visibleRows.map(\.id))) }
    }

    private var sidebar: some View {
        List(selection: Binding<NetworkInterface?>(
            get: { interface }, set: { if let value = $0 { interfaceName = value.rawValue } }
        )) {
            Section("Verbindungen") {
                ForEach(NetworkInterface.allCases) { connection in
                    Label(connection.title, systemImage: connection.symbol)
                        .badge(model.isLoaded ? Text("\((model.draft[connection] ?? []).count)") : Text(""))
                        .tag(connection)
                }
            }
        }
        .listStyle(.sidebar)
        .disabled(!available)
        .accessibilityLabel("Netzwerkverbindung")
    }

    private var detail: some View {
        VStack(spacing: 0) {
            notices
            Group {
                if model.isLoaded {
                    networkTable
                } else {
                    welcome
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            statusBar
        }
        // Bound wrapping before the split view measures its minimum size.
        .frame(minWidth: Self.minimumDetailWidth, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var networkTable: some View {
        Table(visibleRows, selection: $selection) {
            TableColumn("IP-Bereich") { row in
                Text(row.notation).monospaced()
            }
            .width(min: 190, ideal: 250)
            TableColumn("Version", value: \.version).width(65)
            TableColumn("Status") { row in
                Label(row.status.rawValue, systemImage: row.status.symbol)
                    .foregroundStyle(row.status == .invalid ? Color.orange : Color.secondary)
                    .accessibilityLabel(row.status.rawValue)
            }
            .width(min: 110, ideal: 125)
        }
        .disabled(model.busy)
        .searchable(text: $searchText, placement: .toolbar, prompt: "IP-Bereiche suchen")
        .searchFocused($searchFocused)
        .onDeleteCommand {
            guard model.canEdit, available, !searchFocused else { return }
            model.remove(selection, interface: interface)
        }
        .onCopyCommand(perform: selectedRows.isEmpty ? nil : {
            [NSItemProvider(object: selectedRows.map(\.notation).joined(separator: "\n") as NSString)]
        })
        .onKeyPress(.return) {
            guard available, model.canEdit, !searchFocused, selectedRows.count == 1 else { return .ignored }
            perform(.edit)
            return .handled
        }
        .contextMenu(forSelectionType: Int.self) { items in
            Button("IP-Bereich bearbeiten…") { edit(items) }
                .disabled(items.count != 1 || !model.canEdit)
            Button("Kopieren") { copy(items) }.disabled(items.isEmpty)
            Divider()
            Button("Entfernen", role: .destructive) { model.remove(items, interface: interface) }
                .disabled(items.isEmpty || !model.canEdit)
        } primaryAction: { items in
            edit(items)
        }
        .overlay {
            if visibleRows.isEmpty {
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "Keine Freigaben" : "Keine Treffer", systemImage: searchText.isEmpty ? interface.symbol : "magnifyingglass")
                } description: {
                    Text(searchText.isEmpty
                         ? "Für \(interface.title) gelten die regulären lokalen Netzwerkberechtigungen."
                         : "Kein IP-Bereich entspricht „\(searchText)“.")
                } actions: {
                    if searchText.isEmpty {
                        Button("Netzbereich hinzufügen…") { perform(.add) }.disabled(!model.canEdit)
                    } else {
                        Button("Suche löschen") { searchText = "" }
                    }
                }
            }
        }
        .accessibilityLabel("IP-Bereiche für \(interface.title)")
    }

    private var welcome: some View {
        ContentUnavailableView {
            Label {
                Text("Lokale Netzfreigaben")
            } icon: {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().scaledToFit().frame(width: 72, height: 72)
            }
        } description: {
            Text("Verwalte IP-Bereiche, die alle Apps auf diesem Mac ohne lokale Netzwerkabfrage erreichen dürfen. Zum Laden sind Administratorrechte nötig.")
                .frame(maxWidth: 390)
        } actions: {
            Button("Konfiguration laden…") { perform(.load) }
                .buttonStyle(.borderedProminent).disabled(!available)
            Button("Mit Beispieldaten ausprobieren") { perform(.preview) }.disabled(!available)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Button(model.isLoaded ? "Konfiguration neu laden" : "Konfiguration laden", systemImage: "arrow.clockwise") {
                perform(.load)
            }
            .help("Konfiguration laden (⌘L)")
            .disabled(!available)
        }
        ToolbarSpacer(.fixed)
        ToolbarItemGroup {
            Button("Netzbereich hinzufügen", systemImage: "plus") { perform(.add) }
                .help("Netzbereich hinzufügen (⌘N)").disabled(!available || !model.canEdit)
            Button("Auswahl entfernen", systemImage: "minus") { model.remove(selection, interface: interface) }
                .help("Ausgewählte IP-Bereiche entfernen").disabled(!available || !model.canEdit || selectedRows.isEmpty)
        }
        ToolbarSpacer(.fixed)
        ToolbarItem(placement: .primaryAction) {
            Button("Änderungen prüfen…") { perform(.review) }
                .help("Änderungen vor dem Übernehmen prüfen (⌘S)")
                .disabled(!available || !model.canReview)
        }
        ToolbarItem {
            Button("Informationen", systemImage: "sidebar.right") { showsInspector.toggle() }
                .help("Informationen ein- oder ausblenden (⌥⌘I)")
                .disabled(!available || !model.isLoaded)
                .accessibilityValue(showsInspector ? "Eingeblendet" : "Ausgeblendet")
        }
    }

    private var notices: some View {
        VStack(spacing: 0) {
            if model.isDemo {
                banner("Vorschau", symbol: "eye", text: "Beispieldaten. Die Systemeinstellungen bleiben unverändert.") {
                    Button("Vorschau beenden") { perform(.preview) }.disabled(!available)
                }
            } else if model.recoveryBlocked {
                banner("Entwurfsdatei geschützt", symbol: "exclamationmark.triangle", text: "Prüfe die Zugriffsrechte im HallPass-Ordner und starte HallPass erneut, bevor du Änderungen vornimmst.") {
                    EmptyView()
                }
            } else if model.requiresReload {
                banner("Systemzustand prüfen", symbol: "exclamationmark.triangle", text: "Lade die Konfiguration neu. Der Entwurf und das automatische Backup bleiben bis dahin erhalten.") {
                    Button("Neu laden…") { perform(.load) }.disabled(!available)
                }
            } else if model.recoveredDraft {
                banner("Entwurf wiederhergestellt", symbol: "arrow.counterclockwise", text: "Noch nicht übernommen. Beim Speichern wird der Systemzustand erneut geprüft.") {
                    EmptyView()
                }
            }

            if model.needsRestart, !model.isDemo {
                banner("Neustart erforderlich", symbol: "restart", text: "Die gespeicherten Freigaben werden erst nach einem Neustart wirksam.") {
                    EmptyView()
                }
            }

            if model.isLoaded, model.validationMessage != nil {
                banner("Ungültige IP-Bereiche", symbol: "exclamationmark.triangle", text: "Korrigiere oder entferne die markierten Werte vor dem Übernehmen.") {
                    Button("Informationen") { showsInspector = true }
                }
            }
        }
    }

    private func banner<Actions: View>(_ title: String, symbol: String, text: String, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol).foregroundStyle(.secondary).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.callout.bold())
                    Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                actions().controlSize(.small)
            }
            .padding(12)
            Divider()
        }
        .background(.background)
    }

    private var statusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                if model.busy {
                    ProgressView().controlSize(.small)
                    Text(model.activity == .loading ? "Konfiguration wird geladen…" : "Änderungen werden übernommen…")
                } else if let notice = model.notice {
                    Text(notice)
                } else if model.isLoaded {
                    Text(searchText.isEmpty ? "\(rows.count) IP-Bereiche" : "\(visibleRows.count) von \(rows.count) IP-Bereichen")
                    if !selection.isEmpty { Text("· \(selection.count) ausgewählt") }
                } else {
                    Text("Keine Konfiguration geladen")
                }
                Spacer(minLength: 8)
                if model.isDirty { Label("Nicht übernommen", systemImage: "pencil") }
            }
            .font(.callout).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 10)
            .fixedSize(horizontal: false, vertical: true)
        }
        .background(.bar)
    }

    private func perform(_ command: WorkspaceCommand) {
        guard available else { return }
        switch command {
        case .add:
            guard model.canEdit else { return }
            sheet = .add
        case .edit:
            edit(selection)
        case .remove:
            guard !searchFocused else { return }
            model.remove(selection, interface: interface)
        case .review:
            guard model.canReview else { return }
            sheet = .review
        case .load:
            if model.isDirty { confirmation = .reload } else { Task { await model.load() } }
        case .discard:
            confirmation = .discard
        case .reset:
            confirmation = .reset
        case .preview:
            guard model.isDemo else { model.startDemo(); return }
            if model.isDirty { confirmation = .leavePreview } else { model.leaveDemo() }
        case .importBackup:
            guard model.canEdit, let window else { return }
            showingFilePanel = true
            BackupPanels.open(in: window) { url in
                showingFilePanel = false
                if let url { model.importBackup(from: url) }
            }
        case .exportBackup:
            guard model.isLoaded, let window else { return }
            showingFilePanel = true
            BackupPanels.save(in: window) { url in
                showingFilePanel = false
                if let url { model.exportBackup(to: url) }
            }
        case .backups:
            model.showBackups()
        case .inspector:
            showsInspector.toggle()
        case .search:
            searchFocused = true
        case .wifi:
            interfaceName = NetworkInterface.wifi.rawValue
        case .ethernet:
            interfaceName = NetworkInterface.ethernet.rawValue
        case .help:
            sheet = .help
        }
    }

    private func edit(_ items: Set<Int>) {
        guard available, model.canEdit, items.count == 1,
              let row = rows.first(where: { items.contains($0.id) }) else { return }
        selection = items
        sheet = .edit(row)
    }

    private func copy(_ items: Set<Int>) {
        let text = rows.filter { items.contains($0.id) }.map(\.notation).joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func confirm(_ pending: DraftConfirmation) {
        confirmation = nil
        switch pending {
        case .reload: Task { await model.load() }
        case .discard: model.discard()
        case .reset: model.resetDraft()
        case .leavePreview: model.leaveDemo()
        }
    }
}

private enum WorkspaceSheet: Identifiable {
    case add, edit(NetworkRow), review, help

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let row): "edit-\(row.id)"
        case .review: "review"
        case .help: "help"
        }
    }
}

private enum DraftConfirmation {
    case reload, discard, reset, leavePreview

    var title: String {
        switch self {
        case .reload: "Entwurf verwerfen und neu laden?"
        case .discard: "Änderungen verwerfen?"
        case .reset: "Alle Freigaben entfernen?"
        case .leavePreview: "Vorschau beenden?"
        }
    }

    var message: String {
        switch self {
        case .reload: "Die nicht übernommenen Änderungen werden durch den Systemzustand ersetzt."
        case .discard: "Der Entwurf wird auf den zuletzt geladenen oder gespeicherten Zustand zurückgesetzt. Du kannst dies widerrufen."
        case .reset: "Die Freigaben für WLAN und Ethernet werden im Entwurf entfernt. Erst Übernehmen und ein Neustart ändern die wirksamen Einstellungen."
        case .leavePreview: "Die nicht übernommenen Änderungen an den Beispieldaten werden verworfen."
        }
    }

    var actionTitle: String {
        switch self {
        case .reload: "Verwerfen und laden"
        case .discard: "Änderungen verwerfen"
        case .reset: "Zum Entfernen vormerken"
        case .leavePreview: "Vorschau beenden"
        }
    }
}
