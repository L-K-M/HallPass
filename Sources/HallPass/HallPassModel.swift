import AppKit
import Foundation
import HallPassCore
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class HallPassModel {
    var snapshot: PreferencesSnapshot?
    var draft = NetworkConfiguration()
    var selectedInterface: NetworkInterface = .wifi
    var busy = false
    var notice: String?
    var error: String?
    var needsRestart = false
    var lastBackup: URL?
    private(set) var isDemo: Bool
    private let service = SystemPreferencesService()

    init(demo: Bool = false) {
        isDemo = demo
        if demo {
            draft = .example
            snapshot = try? PreferencesSnapshot(configuration: draft)
        }
    }

    var isLoaded: Bool { snapshot != nil }
    var isDirty: Bool { snapshot.map { $0.configuration != draft } ?? false }
    var networks: [String] { draft[selectedInterface] ?? [] }
    var totalCount: Int { Set((draft.wifi ?? []) + (draft.ethernet ?? [])).count }
    var plan: PreferencePlan? {
        guard let snapshot else { return nil }
        return try? PreferencePlan(baseline: snapshot, desired: draft)
    }
    var validationMessage: String? {
        do { try draft.validate(); return nil } catch { return error.localizedDescription }
    }

    func startDemo() {
        guard !busy, !isLoaded else { return }
        isDemo = true
        draft = .example
        snapshot = try? PreferencesSnapshot(configuration: draft)
        needsRestart = false
        notice = nil
    }

    func leaveDemo() {
        guard isDemo, !busy else { return }
        isDemo = false
        snapshot = nil
        draft = .init()
        notice = nil
        restoreRestartState()
    }

    func load() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let result = isDemo ? try PreferencesSnapshot(configuration: .example) : try await service.load()
            snapshot = result
            draft = result.configuration
            notice = nil
        } catch { self.error = error.localizedDescription }
    }

    func add(_ notation: String, interfaces: [NetworkInterface]) throws {
        let canonical = try CIDR(notation).notation
        var candidate = draft
        for interface in interfaces {
            var values = candidate[interface] ?? []
            let exists = values.contains { (try? CIDR($0).notation) == canonical }
            if !exists { values.append(canonical) }
            guard values.count <= 512 else { throw ConfigurationError.tooManyNetworks }
            candidate[interface] = values
        }
        draft = candidate
    }

    func remove(_ notation: String) {
        draft[selectedInterface] = networks.filter { $0 != notation }
        if networks.isEmpty { draft[selectedInterface] = nil }
    }

    func discard() {
        if let snapshot { draft = snapshot.configuration }
    }

    func resetDraft() {
        draft = NetworkConfiguration()
        notice = nil
    }

    func save() async {
        guard !busy, isDirty, let snapshot else { return }
        busy = true
        defer { busy = false }
        do {
            let plan = try PreferencePlan(baseline: snapshot, desired: draft)
            if isDemo {
                self.snapshot = try PreferencesSnapshot(configuration: draft)
                notice = nil
                return
            }
            lastBackup = try writeAutomaticBackup(snapshot.configuration)
            let result = try await service.save(plan)
            self.snapshot = result
            draft = result.configuration
            needsRestart = true
            markRestartRequired()
            notice = nil
        } catch {
            if let serviceError = error as? PreferencesServiceError {
                switch serviceError {
                case .rollbackFailed, .verificationFailed:
                    self.snapshot = nil
                    needsRestart = true
                    markRestartRequired()
                default: break
                }
            }
            self.error = error.localizedDescription
        }
    }

    func exportBackup() {
        guard let snapshot else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "HallPass-Backup.json"
        panel.title = "Gespeicherte Konfiguration sichern"
        panel.message = "Das Backup enthält den zuletzt geladenen oder gespeicherten Zustand."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ConfigurationBackup(configuration: snapshot.configuration).encoded().write(to: url, options: .atomic)
            notice = "Backup exportiert."
        } catch { self.error = error.localizedDescription }
    }

    func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "HallPass-Backup als Entwurf öffnen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 1_048_576 else { throw ConfigurationError.unsupportedBackup }
            draft = try ConfigurationBackup.decode(Data(contentsOf: url)).configuration
            notice = nil
        } catch { self.error = error.localizedDescription }
    }

    func showBackups() {
        if let lastBackup { NSWorkspace.shared.activateFileViewerSelecting([lastBackup]) }
        else {
            do {
                let url = try backupDirectory()
                NSWorkspace.shared.open(url)
            } catch { self.error = error.localizedDescription }
        }
    }

    func restoreRestartState() {
        guard !isDemo else { return }
        let savedUptime = UserDefaults.standard.double(forKey: "restartRequiredAtUptime")
        let savedBoot = UserDefaults.standard.double(forKey: "restartRequiredBootTime")
        let boot = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        needsRestart = savedUptime > 0 && abs(boot - savedBoot) < 5
    }

    private func markRestartRequired() {
        let uptime = ProcessInfo.processInfo.systemUptime
        UserDefaults.standard.set(uptime, forKey: "restartRequiredAtUptime")
        UserDefaults.standard.set(Date().timeIntervalSince1970 - uptime, forKey: "restartRequiredBootTime")
    }

    private func backupDirectory() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = root.appendingPathComponent("HallPass/Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return directory
    }

    private func writeAutomaticBackup(_ configuration: NetworkConfiguration) throws -> URL {
        let name = "HallPass-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-"))-\(UUID().uuidString.prefix(8)).json"
        let url = try backupDirectory().appendingPathComponent(name)
        try ConfigurationBackup(configuration: configuration).encoded().write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url
    }
}
