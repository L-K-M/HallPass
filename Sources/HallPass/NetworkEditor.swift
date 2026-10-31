import SwiftUI
import HallPassCore

struct NetworkEditor: View {
    private enum Scope: String, CaseIterable {
        case selected, both
    }

    let model: HallPassModel
    let interface: NetworkInterface
    private let entry: NetworkRow?
    @Environment(\.dismiss) private var dismiss
    @State private var input: String
    @State private var scope = Scope.both
    @State private var failure: String?
    @FocusState private var focused: Bool

    init(model: HallPassModel, interface: NetworkInterface, entry: NetworkRow? = nil) {
        self.model = model
        self.interface = interface
        self.entry = entry
        _input = State(initialValue: entry?.notation ?? "")
    }

    private var parsed: CIDR? { try? CIDR(input) }
    private var title: String { entry == nil ? "Netzbereich hinzufügen" : "Netzbereich bearbeiten" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.title2.bold())
                Text("Die Ausnahme gilt für alle Apps auf diesem Mac. Änderungen bleiben bis zum Übernehmen im Entwurf.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)

            Form {
                Section {
                    TextField("IP-Bereich", text: $input, prompt: Text("192.168.1.0/24"))
                        .monospaced().textFieldStyle(.roundedBorder)
                        .focused($focused).onSubmit(save)
                        .accessibilityHint("IPv4- oder IPv6-Adresse mit Netzpräfix, zum Beispiel 192.168.1.0/24")

                    if let parsed {
                        if parsed.notation != input.trimmingCharacters(in: .whitespacesAndNewlines) {
                            LabeledContent("Netzadresse") {
                                Text(parsed.notation).monospaced().textSelection(.enabled)
                            }
                        }
                        if parsed.prefixLength == 0 {
                            Label("Dieser Bereich umfasst alle IPv\(parsed.isIPv6 ? "6" : "4")-Adressen.", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("Adresse")
                } footer: {
                    Text("CIDR-Notation: IPv4 /0 bis /32, IPv6 /0 bis /128. Für eine einzelne Adresse: /32 oder /128. Host-Bits werden zur Netzadresse normalisiert.")
                }

                Section("Verbindung") {
                    if entry == nil {
                        Picker("Hinzufügen zu", selection: $scope) {
                            Text(interface.title).tag(Scope.selected)
                            Text("WLAN und Ethernet").tag(Scope.both)
                        }
                    } else {
                        LabeledContent("Bearbeiten in", value: interface.title)
                    }
                }

                Section("Vorlagen") {
                    HStack {
                        preset("Link-Local", value: "169.254.0.0/16")
                        preset("Privates /24", value: "192.168.1.0/24")
                        preset("IPv6 Link-Local", value: "fe80::/10")
                    }
                    Text("Vorlagen füllen nur das Eingabefeld aus. Passe den Bereich an dein Netz an.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.red).padding(.horizontal, 24).padding(.bottom, 16)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            Divider()
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(entry == nil ? "Hinzufügen" : "Ändern", action: save)
                    .keyboardShortcut(.defaultAction).disabled(parsed == nil || !model.canEdit)
            }
            .padding(20)
        }
        .frame(width: 520, height: 540)
        .onAppear { focused = true }
        .onChange(of: input) { failure = nil }
    }

    private func preset(_ title: String, value: String) -> some View {
        Button(title) {
            input = value
            focused = true
        }
        .help(value)
    }

    private func save() {
        guard parsed != nil, model.canEdit else { return }
        do {
            if let entry {
                try model.edit(entry.id, notation: input, interface: interface)
            } else {
                try model.add(input, interfaces: scope == .both ? NetworkInterface.allCases : [interface])
            }
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}
