import AppKit
import HallPassCore
import Observation

enum SessionMode {
    case system, preview
}

@MainActor @Observable
final class HallPassModel {
    enum Activity {
        case idle, loading, saving
    }

    private(set) var snapshot: PreferencesSnapshot?
    private(set) var draft = NetworkConfiguration()
    private(set) var activity = Activity.idle
    private(set) var mode: SessionMode
    private(set) var needsRestart = false
    private(set) var recoveredDraft = false
    private(set) var recoveryBlocked = false
    private(set) var requiresReload = false
    private(set) var notice: String?
    private(set) var lastBackup: URL?
    var error: String?

    @ObservationIgnored private(set) var undoManager = UndoManager()
    private let service: any PreferencesServicing
    private let backups: BackupStore
    private var restoredSession = false

    private enum RestartState {
        static let uptimeKey = "restartRequiredAtUptime"
        static let bootKey = "restartRequiredBootTime"
        static let bootTolerance: TimeInterval = 5
    }

    init(mode: SessionMode = .system, backups: BackupStore = .init(), service: any PreferencesServicing = SystemPreferencesService()) {
        self.mode = mode
        self.backups = backups
        self.service = service
        if mode == .preview {
            draft = .example
            snapshot = try? PreferencesSnapshot(configuration: draft)
        }
    }

    var isDemo: Bool { mode == .preview }
    var isLoaded: Bool { snapshot != nil }
    var busy: Bool { activity != .idle }
    var isDirty: Bool { snapshot.map { $0.configuration != draft } ?? false }
    var canEdit: Bool { isLoaded && !busy && !requiresReload && (isDemo || !recoveryBlocked) }
    var canReview: Bool { canEdit && isDirty && validationMessage == nil }
    var changes: [InterfaceChange] { draft.changes(from: snapshot?.configuration ?? .init()) }

    var validationMessage: String? {
        do {
            try draft.validate()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func useUndoManager(_ manager: UndoManager?) {
        guard let manager, manager !== undoManager else { return }
        undoManager.removeAllActions()
        undoManager = manager
    }

    func restoreSession() {
        guard !restoredSession else { return }
        restoredSession = true
        guard !isDemo else { return }
        restoreRestartState()

        do {
            guard let recovery = try backups.loadRecovery() else { return }
            let baseline = try recovery.baseline
            guard recovery.draft != baseline.configuration else { return }
            snapshot = baseline
            draft = recovery.draft
            recoveredDraft = true
        } catch {
            let failure = error.localizedDescription
            do {
                let preserved = try backups.preserveFailedRecovery()
                self.error = "Der Entwurf konnte nicht wiederhergestellt werden. Das Original liegt unverändert im Backupordner als „\(preserved.lastPathComponent)“.\n\n\(failure)"
            } catch {
                recoveryBlocked = true
                self.error = "Die ursprüngliche Entwurfsdatei bleibt unverändert. Bearbeiten ist gesperrt, weil sie nicht gesichert werden konnte. Prüfe die Zugriffsrechte im HallPass-Ordner und starte HallPass erneut.\n\n\(error.localizedDescription)"
            }
        }
    }

    func startDemo() {
        guard !busy, !isLoaded else { return }
        mode = .preview
        draft = .example
        snapshot = try? PreferencesSnapshot(configuration: draft)
        needsRestart = false
        notice = nil
        undoManager.removeAllActions()
    }

    func leaveDemo() {
        guard isDemo, !busy else { return }
        mode = .system
        snapshot = nil
        draft = .init()
        notice = nil
        undoManager.removeAllActions()
        restoreRestartState()
    }

    func load() async {
        guard !busy else { return }
        activity = .loading
        defer { activity = .idle }

        do {
            let result = isDemo ? try PreferencesSnapshot(configuration: .example) : try await service.load()
            snapshot = result
            draft = result.configuration
            recoveredDraft = false
            requiresReload = false
            notice = nil
            undoManager.removeAllActions()
            persistRecovery()
        } catch PreferencesServiceError.cancelled {
            notice = "Laden abgebrochen. Der Entwurf bleibt erhalten."
        } catch {
            self.error = error.localizedDescription
        }
    }

    func add(_ notation: String, interfaces: [NetworkInterface]) throws {
        guard canEdit else { return }
        let candidate = try draft.adding(notation, to: interfaces)
        guard candidate != draft else { throw ConfigurationError.duplicateNetwork }
        replaceDraft(candidate, actionName: "Netzbereich hinzufügen")
    }

    func edit(_ index: Int, notation: String, interface: NetworkInterface) throws {
        guard canEdit else { return }
        let candidate = try draft.replacing(index, with: notation, in: interface)
        replaceDraft(candidate, actionName: "Netzbereich bearbeiten")
    }

    func remove(_ indices: Set<Int>, interface: NetworkInterface) {
        guard canEdit else { return }
        let candidate = draft.removing(indices, from: interface)
        replaceDraft(candidate, actionName: indices.count == 1 ? "Netzbereich entfernen" : "Netzbereiche entfernen")
    }

    func discard() {
        guard canEdit, let snapshot else { return }
        replaceDraft(snapshot.configuration, actionName: "Änderungen verwerfen")
    }

    func discardForClosing() -> Bool {
        guard !busy, let snapshot else { return false }
        do {
            if !isDemo, !recoveryBlocked { try backups.removeRecovery() }
        } catch {
            self.error = "Der wiederherstellbare Entwurf konnte nicht entfernt werden.\n\n\(error.localizedDescription)"
            return false
        }
        draft = snapshot.configuration
        recoveredDraft = false
        undoManager.removeAllActions()
        return true
    }

    func resetDraft() {
        guard canEdit else { return }
        replaceDraft(.init(), actionName: "Alle Freigaben entfernen")
    }

    func save() async {
        guard canReview, let snapshot else { return }
        activity = .saving
        defer { activity = .idle }

        do {
            let plan = try PreferencePlan(baseline: snapshot, desired: draft)
            if isDemo {
                self.snapshot = try PreferencesSnapshot(configuration: draft)
                undoManager.removeAllActions()
                notice = "Vorschau übernommen. Die Systemeinstellungen bleiben unverändert."
                return
            }

            lastBackup = try backups.automaticBackup(snapshot.configuration)
            let result = try await service.save(plan)
            self.snapshot = result
            draft = result.configuration
            needsRestart = true
            recoveredDraft = false
            markRestartRequired()
            undoManager.removeAllActions()
            notice = nil
            persistRecovery()
        } catch PreferencesServiceError.cancelled {
            notice = "Übernehmen abgebrochen. Der Entwurf bleibt erhalten."
        } catch {
            if let serviceError = error as? PreferencesServiceError {
                switch serviceError {
                case .rollbackFailed, .verificationFailed:
                    requiresReload = true
                    needsRestart = true
                    markRestartRequired()
                default:
                    break
                }
            }
            self.error = error.localizedDescription
        }
    }

    func exportBackup(to url: URL) {
        guard !busy, let snapshot else { return }
        do {
            try backups.export(snapshot.configuration, to: url)
            notice = "Gespeicherten Zustand exportiert."
        } catch {
            self.error = error.localizedDescription
        }
    }

    func importBackup(from url: URL) {
        guard canEdit else { return }
        do {
            let configuration = try backups.readBackup(at: url)
            replaceDraft(configuration, actionName: "Backup importieren")
            notice = "Backup als Entwurf geöffnet. Änderungen vor dem Übernehmen prüfen."
        } catch {
            self.error = error.localizedDescription
        }
    }

    func showBackups() {
        guard !isDemo else { return }
        do {
            if let lastBackup {
                NSWorkspace.shared.activateFileViewerSelecting([lastBackup])
                return
            }
            NSWorkspace.shared.open(try backups.backupsDirectory())
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func replaceDraft(_ candidate: NetworkConfiguration, actionName: String) {
        guard candidate != draft else { return }
        let previous = draft
        let startsGroup = !undoManager.isUndoing && !undoManager.isRedoing
        if startsGroup { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { target.replaceDraft(previous, actionName: actionName) }
        }
        undoManager.setActionName(actionName)
        if startsGroup { undoManager.endUndoGrouping() }

        draft = candidate
        notice = nil
        persistRecovery()
    }

    private func persistRecovery() {
        guard !isDemo, !recoveryBlocked, let snapshot else { return }
        do {
            if isDirty {
                try backups.saveRecovery(DraftRecovery(baseline: snapshot, draft: draft))
            } else {
                try backups.removeRecovery()
                recoveredDraft = false
            }
        } catch {
            self.error = "Der Entwurf ist im Fenster erhalten, konnte aber nicht zur Wiederherstellung gesichert werden.\n\n\(error.localizedDescription)"
        }
    }

    private func restoreRestartState() {
        let savedUptime = UserDefaults.standard.double(forKey: RestartState.uptimeKey)
        let savedBoot = UserDefaults.standard.double(forKey: RestartState.bootKey)
        let boot = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        needsRestart = savedUptime > 0 && abs(boot - savedBoot) < RestartState.bootTolerance
    }

    private func markRestartRequired() {
        let uptime = ProcessInfo.processInfo.systemUptime
        UserDefaults.standard.set(uptime, forKey: RestartState.uptimeKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970 - uptime, forKey: RestartState.bootKey)
    }
}
