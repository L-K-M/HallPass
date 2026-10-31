import SwiftUI
import HallPassCore

enum Palette {
    static let green = Color(nsColor: NSColor(name: "HallPassAccent") { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.43, green: 0.76, blue: 0.64, alpha: 1)
        }
        return NSColor(calibratedRed: 0.13, green: 0.43, blue: 0.35, alpha: 1)
    })
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let background = Color(nsColor: .windowBackgroundColor)
}

struct InfoButton: View {
    let title: String
    let documentation: String
    var appleLink = false
    @State private var isOpen = false

    var body: some View {
        Button { isOpen.toggle() } label: {
            Image(systemName: "info.circle").font(.system(size: 14)).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel("Informationen: \(title)")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(documentation).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                if appleLink {
                    Link("Apple-Dokumentation ↗", destination: URL(string: "https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy")!)
                        .font(.system(size: 11))
                }
            }
            .padding(18).frame(width: 295).tint(Palette.green)
        }
    }
}

struct TicketMark: View {
    var size: CGFloat = 36
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "HallPass", withExtension: "icns"),
               let icon = NSImage(contentsOf: url) {
                Image(nsImage: icon).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "ticket.fill").font(.system(size: size * 0.7)).foregroundStyle(Palette.green)
            }
        }
        .frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct ContentView: View {
    @Bindable var model: HallPassModel
    @State private var showingAdd = false
    @State private var showingReview = false
    @State private var confirmingReset = false
    @State private var confirmingReload = false
    @State private var confirmingImport = false
    @State private var confirmingLeaveDemo = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                header
                if model.isLoaded { editor } else { welcome }
                footer
            }
            .padding(.horizontal, 28).padding(.top, 43).padding(.bottom, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.background).tint(Palette.green)
        .background(WindowAccessor(model: model).frame(width: 0, height: 0))
        .sheet(isPresented: $showingAdd) { AddNetworkView(model: model) }
        .sheet(isPresented: $showingReview) { ReviewView(model: model) }
        .alert("HallPass", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .confirmationDialog("Alle Freigaben entfernen?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Zum Entfernen vormerken", role: .destructive) { model.resetDraft() }
        } message: { Text("Die Änderung wird erst mit Übernehmen gespeichert.") }
        .confirmationDialog("Entwurf verwerfen und neu laden?", isPresented: $confirmingReload, titleVisibility: .visible) {
            Button("Verwerfen und laden", role: .destructive) { Task { await model.load() } }
        }
        .confirmationDialog("Entwurf durch Backup ersetzen?", isPresented: $confirmingImport, titleVisibility: .visible) {
            Button("Backup auswählen") { model.importBackup() }
        }
        .confirmationDialog("Vorschau beenden und Entwurf verwerfen?", isPresented: $confirmingLeaveDemo, titleVisibility: .visible) {
            Button("Vorschau beenden", role: .destructive) { model.leaveDemo() }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                TicketMark(size: 32)
                Text("HallPass").font(.system(size: 20, weight: .semibold, design: .rounded)).tracking(-0.6)
            }.padding(.top, 43).padding(.bottom, 32)
            ForEach(NetworkInterface.allCases) { interface in
                Button { model.selectedInterface = interface } label: {
                    HStack(spacing: 10) {
                        Image(systemName: interface.symbol).font(.system(size: 15)).frame(width: 19)
                        Text(interface.title).font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(model.isLoaded ? "\((model.draft[interface] ?? []).count)" : "–")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 11)
                    .background(model.selectedInterface == interface ? Palette.green.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.bottom, 5)
                .accessibilityLabel("\(interface.title), \((model.draft[interface] ?? []).count) Freigaben")
            }
            Spacer()
            Menu {
                Button("Gespeicherten Zustand exportieren…", action: model.exportBackup)
                Button("Backup importieren…") {
                    if model.isDirty { confirmingImport = true } else { model.importBackup() }
                }
                Divider()
                Button("Backupordner öffnen", action: model.showBackups).disabled(model.isDemo)
                Divider()
                Button("Alle Freigaben entfernen…", role: .destructive) { confirmingReset = true }
            } label: { Label("Backups", systemImage: "clock.arrow.circlepath").font(.system(size: 11)) }
                .menuStyle(.borderlessButton).disabled(!model.isLoaded || model.busy)
        }
        .padding(.horizontal, 16).padding(.bottom, 24)
        .frame(width: 180).frame(maxHeight: .infinity)
        .background(Palette.green.opacity(0.025))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Netzfreigaben").font(.system(size: 23, weight: .semibold)).tracking(-0.6)
            InfoButton(title: "Netzfreigaben", documentation: "Die eingetragenen IP-Bereiche sind für alle Apps auf diesem Mac erreichbar, unabhängig von deren lokaler Netzwerkberechtigung. Die Ausnahmen gelten in jedem Netz mit diesen Adressen. WLAN und Ethernet werden getrennt verwaltet.", appleLink: true)
            Spacer(minLength: 6)
            if model.isDemo {
                HStack(spacing: 6) {
                    Text("Vorschau").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.green)
                    InfoButton(title: "Vorschau", documentation: "Du arbeitest mit Beispielwerten. Änderungen bleiben im Arbeitsspeicher; die Systemeinstellungen werden weder gelesen noch verändert.")
                    Button {
                        if model.isDirty { confirmingLeaveDemo = true } else { model.leaveDemo() }
                    } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)) }
                    .buttonStyle(.plain).help("Vorschau beenden").accessibilityLabel("Vorschau beenden")
                }
            } else if model.needsRestart {
                HStack(spacing: 6) {
                    Label("Neustart nötig", systemImage: "arrow.clockwise").font(.system(size: 10)).foregroundStyle(.orange)
                    InfoButton(title: "Neustart erforderlich", documentation: "Die Änderungen sind gespeichert. macOS übernimmt sie erst nach einem Neustart. HallPass startet deinen Mac nicht automatisch neu.")
                }
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.rectangle.on.rectangle").font(.system(size: 32, weight: .light)).foregroundStyle(Palette.green)
            HStack(spacing: 9) {
                Button { Task { await model.load() } } label: {
                    Text(model.busy ? "Wird geladen …" : "Konfiguration laden").padding(.horizontal, 7).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).disabled(model.busy).keyboardShortcut("l", modifiers: .command)
                InfoButton(title: "Konfiguration laden", documentation: "macOS fragt nach Administratorrechten, damit HallPass die systemweiten Einstellungen lesen kann. Beim Laden wird nichts verändert. Erst nach Änderungen prüfen und Übernehmen werden die angezeigten Ausnahmen gespeichert.")
            }
            Button("Vorschau") { model.startDemo() }.buttonStyle(.link).font(.system(size: 11)).disabled(model.busy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(20)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.primary.opacity(0.06)))
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("IP-Bereiche").font(.system(size: 12, weight: .semibold))
                Text("\(model.networks.count)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Button { showingAdd = true } label: { Label("Hinzufügen", systemImage: "plus").font(.system(size: 11, weight: .medium)) }
                    .buttonStyle(.bordered).disabled(model.busy).keyboardShortcut("n", modifiers: .command)
            }.padding(16)
            Divider()
            if model.networks.isEmpty {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Keine Freigaben").font(.system(size: 13)).foregroundStyle(.secondary)
                        InfoButton(title: "Keine Freigaben", documentation: "Für diese Verbindung sind keine Ausnahmen konfiguriert. Apps benötigen für lokale Netzwerkzugriffe ihre reguläre Berechtigung.")
                    }
                    Button("Hinzufügen") { showingAdd = true }.buttonStyle(.link).font(.system(size: 11))
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.networks.enumerated()), id: \.offset) { index, network in
                            networkRow(network)
                            if index < model.networks.count - 1 { Divider().padding(.leading, 16) }
                        }
                    }
                }.frame(maxHeight: .infinity)
            }
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.primary.opacity(0.07)))
        .disabled(model.busy)
    }

    private func networkRow(_ network: String) -> some View {
        let cidr = try? CIDR(network)
        let isNew = !(model.snapshot?.configuration[model.selectedInterface] ?? []).contains(network)
        return HStack(spacing: 12) {
            Text(network).font(.system(size: 13, weight: .medium, design: .monospaced)).textSelection(.enabled)
            Spacer()
            if cidr == nil {
                InfoButton(title: "Ungültiger Altwert", documentation: "Dieser vorhandene Wert ist keine gültige CIDR-Notation. Entferne ihn vor dem Speichern oder ersetze ihn durch einen gültigen IP-Bereich.")
            } else {
                Text(cidr!.isIPv6 ? "IPv6" : "IPv4").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            if isNew { Circle().fill(Palette.green).frame(width: 5, height: 5).help("Neu im Entwurf") }
            Button { model.remove(network) } label: {
                Image(systemName: "minus.circle").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).help("Entfernen").accessibilityLabel("\(network) entfernen")
        }.padding(.horizontal, 16).padding(.vertical, 17)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if model.busy { ProgressView().controlSize(.small) }
            Button {
                if model.isDirty { confirmingReload = true } else { Task { await model.load() } }
            } label: { Image(systemName: "arrow.clockwise") }
            .help("Neu laden").accessibilityLabel("Neu laden").disabled(model.busy || !model.isLoaded)
            if model.isDirty {
                Button("Verwerfen", action: model.discard).buttonStyle(.plain).font(.system(size: 11)).disabled(model.busy)
            }
            Spacer()
            if let message = model.validationMessage, model.isLoaded {
                InfoButton(title: "Entwurf prüfen", documentation: message)
            } else if model.isDirty {
                Text("Ungespeichert").font(.system(size: 10)).foregroundStyle(.secondary)
            } else if let notice = model.notice {
                Text(notice).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Button { showingReview = true } label: {
                Text("Änderungen prüfen").font(.system(size: 12, weight: .medium)).padding(.horizontal, 5).padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent).disabled(!model.isDirty || model.busy || model.validationMessage != nil)
            .keyboardShortcut("s", modifiers: .command)
        }
    }
}

struct AddNetworkView: View {
    @Bindable var model: HallPassModel
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var both = true
    @State private var failure: String?
    @FocusState private var focused: Bool
    private var parsed: CIDR? { try? CIDR(input) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Netzbereich hinzufügen").font(.system(size: 19, weight: .semibold)).tracking(-0.5)
                Spacer()
                InfoButton(title: "Netzbereich hinzufügen", documentation: "Die Ausnahme gilt für alle Apps. Einträge werden zunächst zum Entwurf hinzugefügt. Erst Übernehmen speichert sie in macOS.")
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Text("IP-Bereich").font(.system(size: 12, weight: .medium))
                    InfoButton(title: "CIDR-Notation", documentation: "Gib eine IPv4- oder IPv6-Adresse mit Netzpräfix ein, zum Beispiel 192.168.1.0/24 oder fd12:3456::/48. Für eine einzelne Adresse: /32 bei IPv4, /128 bei IPv6. Host-Bits werden automatisch zur Netzadresse normalisiert.")
                }
                TextField("192.168.1.0/24", text: $input).textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, design: .monospaced)).controlSize(.large).focused($focused).onSubmit(add)
                if let parsed, parsed.notation != input.trimmingCharacters(in: .whitespacesAndNewlines) {
                    HStack(spacing: 7) {
                        Text("→ \(parsed.notation)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.green)
                        InfoButton(title: "Netzadresse", documentation: "Die Adresse wurde auf den Anfang des angegebenen Netzes normalisiert. Gespeichert wird dieser gesamte IP-Bereich.")
                    }
                } else if !input.isEmpty && parsed == nil {
                    HStack(spacing: 7) {
                        Text("Ungültiger IP-Bereich").font(.system(size: 11)).foregroundStyle(.orange)
                        InfoButton(title: "IP-Bereich korrigieren", documentation: "Erforderlich sind eine numerische IP-Adresse und ein Präfix: IPv4 /0 bis /32, IPv6 /0 bis /128. Hostnamen, Zonen-IDs und Leerzeichen innerhalb der Adresse sind nicht möglich.")
                    }
                }
            }
            HStack(spacing: 7) {
                preset("Link-Local", "169.254.0.0/16")
                preset("Privates /24", "192.168.1.0/24")
                preset("IPv6 Link-Local", "fe80::/10")
                InfoButton(title: "Vorlagen", documentation: "Link-Local: 169.254.0.0/16. Privates /24: 192.168.1.0/24 als Beispiel – passe es an dein Netz an. IPv6 Link-Local: fe80::/10. Ein Klick füllt nur das Eingabefeld aus.")
            }
            Toggle("WLAN und Ethernet", isOn: $both).font(.system(size: 12))
            if !both { Text("Nur \(model.selectedInterface.title)").font(.system(size: 11)).foregroundStyle(.secondary) }
            if parsed?.prefixLength == 0 {
                HStack(spacing: 7) {
                    Label("Alle IPv\(parsed!.isIPv6 ? "6" : "4")-Adressen", systemImage: "exclamationmark.triangle").font(.system(size: 11)).foregroundStyle(.orange)
                    InfoButton(title: "Ausnahme für /0", documentation: "Dieser Bereich umfasst alle Adressen der gewählten IP-Version. Damit entfallen die lokalen Netzwerkprüfungen für diesen gesamten Adressraum.")
                }
            }
            if let failure { Text(failure).font(.system(size: 11)).foregroundStyle(.orange) }
            Divider()
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Hinzufügen", action: add).buttonStyle(.borderedProminent).disabled(parsed == nil).keyboardShortcut(.defaultAction)
            }
        }.padding(25).frame(width: 455).tint(Palette.green).onAppear { focused = true }
    }

    private func preset(_ title: String, _ value: String) -> some View {
        Button(title) { input = value }.font(.system(size: 10)).buttonStyle(.bordered)
    }
    private func add() {
        guard parsed != nil else { return }
        do {
            try model.add(input, interfaces: both ? NetworkInterface.allCases : [model.selectedInterface])
            dismiss()
        } catch { failure = error.localizedDescription }
    }
}

struct ReviewView: View {
    @Bindable var model: HallPassModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Änderungen übernehmen?").font(.system(size: 20, weight: .semibold)).tracking(-0.5)
                Spacer()
                InfoButton(title: "Änderungen übernehmen", documentation: model.isDemo ? "Vorschau: Die Systemeinstellungen werden nicht verändert." : "Die Ausnahmen gelten für alle Apps. HallPass erstellt vor dem Speichern ein Backup und macOS fragt nach Administratorrechten. Die Änderungen werden nach einem Neustart wirksam.")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(NetworkInterface.allCases) { interface in
                        let before = model.snapshot?.configuration[interface] ?? []
                        let after = model.draft[interface] ?? []
                        let added = after.filter { !before.contains($0) }
                        let removed = before.filter { !after.contains($0) }
                        if model.snapshot?.configuration[interface] != model.draft[interface] {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(interface.title, systemImage: interface.symbol).font(.system(size: 12, weight: .semibold))
                                ForEach(added, id: \.self) { row($0, added: true) }
                                ForEach(removed, id: \.self) { row($0, added: false) }
                                if added.isEmpty && removed.isEmpty {
                                    Label("Leere Einstellung zurücksetzen", systemImage: "minus.circle").font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }.frame(maxHeight: 260)
            Divider()
            HStack {
                Button("Zurück") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(model.isDemo ? "Vorschau übernehmen" : "Übernehmen") {
                    dismiss()
                    Task { await model.save() }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(25).frame(width: 455).tint(Palette.green)
    }

    private func row(_ network: String, added: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: added ? "plus.circle.fill" : "minus.circle.fill").foregroundStyle(added ? Palette.green : Color.orange)
            Text(network).font(.system(size: 12, design: .monospaced))
            Spacer()
        }.accessibilityLabel("\(added ? "Hinzufügen" : "Entfernen"): \(network)")
    }
}
