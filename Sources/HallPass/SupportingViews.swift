import SwiftUI
import HallPassCore

enum HallPassHelp {
    static let appleDocumentation = URL(string: "https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy")!
    static let scope = "Die Freigaben gelten für alle Apps auf diesem Mac und in jedem Netz mit diesen IP-Adressen. WLAN und Ethernet werden getrennt verwaltet."
}

struct NetworkInspector: View {
    static let minimumWidth: CGFloat = 240
    static let idealWidth: CGFloat = 270
    static let maximumWidth: CGFloat = 360

    let rows: [NetworkRow]
    let interface: NetworkInterface
    let canEdit: Bool
    let edit: () -> Void

    var body: some View {
        Group {
            if rows.isEmpty {
                ContentUnavailableView("Kein IP-Bereich ausgewählt", systemImage: "info.circle", description: Text("Wähle einen Eintrag, um Adresse und Geltungsbereich zu prüfen."))
            } else {
                Form {
                    Section(rows.count == 1 ? "IP-Bereich" : "\(rows.count) IP-Bereiche") {
                        if let row = rows.first, rows.count == 1 {
                            Text(row.notation).monospaced().textSelection(.enabled)
                            LabeledContent("Verbindung", value: interface.title)
                            if let cidr = row.cidr {
                                LabeledContent("Version", value: row.version)
                                LabeledContent("Präfix", value: "/\(cidr.prefixLength)")
                                if cidr.notation != row.notation {
                                    LabeledContent("Netzadresse") { Text(cidr.notation).monospaced().textSelection(.enabled) }
                                }
                            }
                            Label(row.status.rawValue, systemImage: row.status.symbol)
                                .foregroundStyle(row.status == .invalid ? Color.orange : Color.secondary)
                            Button("IP-Bereich bearbeiten…", action: edit).disabled(!canEdit)
                        } else {
                            LabeledContent("Verbindung", value: interface.title)
                            Text("Kopiere oder entferne die Auswahl über das Menü „Bearbeiten“ oder das Kontextmenü.")
                        }
                    }

                    Section("Geltungsbereich") {
                        Text(HallPassHelp.scope)
                        Text("Die Freigaben umgehen lokale Netzwerkabfragen. Sie sind keine Firewall-Regeln oder Freigaben für einzelne Apps.")
                            .foregroundStyle(.secondary)
                        if rows.contains(where: { $0.cidr?.prefixLength == 0 }) {
                            Label("Ein /0-Präfix umfasst alle Adressen der jeweiligen IP-Version.", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }

                    if rows.contains(where: { $0.status == .invalid }) {
                        Section("Ungültiger Altwert") {
                            Text("HallPass bewahrt vorhandene Werte unverändert auf. Korrigiere oder entferne ungültige Einträge vor dem Übernehmen.")
                        }
                    }

                    Section("Übernehmen") {
                        Text("Änderungen werden erst nach Prüfung, Administratorbestätigung und einem Neustart wirksam.")
                        Link("Apple-Dokumentation", destination: HallPassHelp.appleDocumentation)
                    }
                }
                .formStyle(.grouped)
            }
        }
        .frame(minWidth: Self.minimumWidth, idealWidth: Self.idealWidth, maxWidth: Self.maximumWidth)
        .accessibilityLabel("Informationen zur Auswahl")
    }
}

struct ReviewView: View {
    let model: HallPassModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Änderungen prüfen").font(.title2.bold())
                Text(model.isDemo ? "Vorschau: Es werden keine Systemeinstellungen geändert." : HallPassHelp.scope)
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)

            List {
                ForEach(model.changes) { change in
                    Section {
                        ForEach(entries(for: change)) { entry in
                            changeRow(entry.network, kind: entry.kind)
                        }
                        if change.added.isEmpty, change.removed.isEmpty {
                            Text(structuralChange(change.interface)).foregroundStyle(.secondary)
                        }
                    } header: {
                        Label(change.interface.title, systemImage: change.interface.symbol)
                    }
                }
            }
            .textSelection(.enabled)

            if !model.isDemo {
                Label("Vor dem Speichern wird ein Backup erstellt. macOS fragt nach Administratorrechten. Ein Neustart ist erforderlich.", systemImage: "externaldrive.badge.timemachine")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(20)
            }

            Divider()
            HStack {
                Button("Weiter bearbeiten") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(model.isDemo ? "Vorschau übernehmen" : "Übernehmen") {
                    dismiss()
                    Task { await model.save() }
                }
                .keyboardShortcut(.defaultAction).disabled(!model.canReview)
            }
            .padding(20)
        }
        .frame(width: 560, height: 500)
    }

    private enum ChangeKind: String {
        case addition, removal
        var title: String { self == .addition ? "Hinzufügen" : "Entfernen" }
        var symbol: String { self == .addition ? "plus.circle" : "minus.circle" }
    }

    private struct ReviewEntry: Identifiable {
        let id: String
        let network: String
        let kind: ChangeKind
    }

    private func entries(for change: InterfaceChange) -> [ReviewEntry] {
        // List flattens row identities across additions, removals, and interfaces.
        [(ChangeKind.addition, change.added), (.removal, change.removed)].flatMap { kind, networks in
            networks.enumerated().map { index, network in
                ReviewEntry(id: "\(change.interface.rawValue)/\(kind.rawValue)/\(index)", network: network, kind: kind)
            }
        }
    }

    private func changeRow(_ network: String, kind: ChangeKind) -> some View {
        HStack(spacing: 10) {
            Image(systemName: kind.symbol).foregroundStyle(kind == .addition ? Color.accentColor : Color.orange)
                .accessibilityHidden(true)
            Text(network).monospaced()
            Spacer()
            Text(kind.title).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func structuralChange(_ interface: NetworkInterface) -> String {
        if model.draft[interface] == nil { return "Leere Einstellung zurücksetzen" }
        if model.snapshot?.configuration[interface] == nil { return "Leere Einstellung anlegen" }
        return "Reihenfolge aktualisieren"
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("HallPass-Hilfe").font(.title2.bold()).padding(24)
            Form {
                Section("Lokale Netzfreigaben") {
                    Text(HallPassHelp.scope)
                    Text("HallPass verwaltet weder WLAN-Namen noch Firewall-Regeln oder Berechtigungen einzelner Apps. Es installiert keinen Hintergrunddienst und benötigt keine Netzwerkverbindung.")
                }
                Section("Konfiguration ändern") {
                    Text("1. Konfiguration laden (⌘L) und als Administrator bestätigen.")
                    Text("2. WLAN oder Ethernet wählen (⌘1 / ⌘2). Mit ⌘N einen IP-Bereich hinzufügen; einen Eintrag mit Doppelklick oder Return bearbeiten.")
                    Text("3. Änderungen prüfen (⌘S), dann Übernehmen wählen. Erst danach den Mac neu starten.")
                    Text("Einträge lassen sich mit ⌘- oder ⇧-Klick gemeinsam auswählen, kopieren und entfernen. Entwurfsänderungen können mit ⌘Z widerrufen werden.")
                }
                Section("IP-Bereiche") {
                    Text("Beispiele: 169.254.0.0/16, 192.168.1.0/24, fe80::/10. Einzelne Adressen verwenden /32 bei IPv4 und /128 bei IPv6. /0 umfasst alle Adressen einer IP-Version.")
                    Text("Pro Verbindung sind bis zu \(NetworkConfiguration.maximumNetworksPerInterface) Einträge möglich. Vorhandene Werte werden beim Laden und Exportieren nicht normalisiert.")
                }
                Section("Backups und Wiederherstellung") {
                    Text("Das Menü „Ablage“ enthält Import, Export und den Backupordner. Exportiert wird der zuletzt geladene oder gespeicherte Zustand. Ein Import ersetzt nur den Entwurf und lässt sich widerrufen.")
                    Text("Vor jedem Übernehmen wird ein Backup in „~/Library/Application Support/HallPass/Backups/“ gesichert. Nicht übernommene Änderungen werden nach einem unerwarteten Ende als Entwurf wiederhergestellt. Vor dem Schreiben prüft HallPass den ursprünglichen Systemzustand erneut.")
                    Text("„Alle Freigaben entfernen“ leert beide Verbindungen im Entwurf. Nach Übernehmen und Neustart gelten wieder die regulären Netzwerkberechtigungen.")
                }
                Section("Weitere Informationen") {
                    Link("Apple TN3179: Local Network Privacy", destination: HallPassHelp.appleDocumentation)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Fertig") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 580, height: 600)
        .onExitCommand { dismiss() }
    }
}
