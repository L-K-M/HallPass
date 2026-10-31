import AppKit
import Foundation
import HallPassCore
import Testing
@testable import HallPass

@MainActor
struct HallPassModelTests {
    @Test func addingToBothInterfacesIsOneNamedUndo() throws {
        let model = preview()
        try model.add("10.1.2.3/8", interfaces: NetworkInterface.allCases)
        #expect(model.draft.wifi?.last == "10.0.0.0/8")
        #expect(model.draft.ethernet?.last == "10.0.0.0/8")
        #expect(model.undoManager.undoActionName == "Netzbereich hinzufügen")

        model.undoManager.undo()
        #expect(model.draft == .example)
        #expect(!model.isDirty)
        model.undoManager.redo()
        #expect(model.draft.wifi?.last == "10.0.0.0/8")
        #expect(model.draft.ethernet?.last == "10.0.0.0/8")
    }

    @Test func editRemovalResetAndDiscardCanBeUndone() throws {
        let model = preview()
        try model.edit(0, notation: "10.0.0.1/32", interface: .wifi)
        let edited = model.draft
        model.remove([0, 1], interface: .wifi)
        #expect(model.draft.wifi == nil)
        #expect(model.undoManager.undoActionName == "Netzbereiche entfernen")
        model.undoManager.undo()
        #expect(model.draft == edited)

        model.resetDraft()
        #expect(model.draft == .init())
        model.undoManager.undo()
        #expect(model.draft == edited)
        model.discard()
        #expect(model.draft == .example)
        model.undoManager.undo()
        #expect(model.draft == edited)
    }

    @Test func importIsUndoableAndExportUsesSavedState() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BackupStore(root: directory)
        let imported = NetworkConfiguration(wifi: ["legacy", "legacy"], ethernet: [])
        let backup = directory.appendingPathComponent("backup.json")
        try store.export(imported, to: backup)
        let model = preview()
        model.importBackup(from: backup)
        #expect(model.draft == imported)
        model.remove([0], interface: .wifi)
        #expect(model.draft.wifi == ["legacy"])
        model.undoManager.undo()
        #expect(model.draft == imported)
        model.undoManager.undo()
        #expect(model.draft == .example)
        model.undoManager.redo()

        let exported = directory.appendingPathComponent("export.json")
        model.exportBackup(to: exported)
        #expect(try store.readBackup(at: exported) == .example)
    }

    @Test func corruptImportDoesNotAlterTheDraftOrUndoHistory() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("invalid.json")
        try Data("not JSON".utf8).write(to: url)
        let model = preview()
        model.importBackup(from: url)
        #expect(model.draft == .example)
        #expect(!model.undoManager.canUndo)
        #expect(model.error != nil)
    }

    @Test func previewCommitEndsDraftUndoWithoutSystemWrites() async throws {
        let model = preview()
        try model.add("10.0.0.0/8", interfaces: [.wifi])
        await model.save()
        #expect(!model.isDirty)
        #expect(!model.undoManager.canUndo)
        #expect(!model.needsRestart)
        #expect(model.lastBackup == nil)
        #expect(model.snapshot?.configuration == model.draft)
    }

    @Test func recoverySurvivesAnotherModelAndDiscardRemovesIt() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BackupStore(root: directory)
        let baseline = try PreferencesSnapshot(configuration: .example)
        let draft = try NetworkConfiguration.example.adding("10.0.0.0/8", to: [.ethernet])
        try store.saveRecovery(DraftRecovery(baseline: baseline, draft: draft))

        let first = HallPassModel(backups: store)
        first.restoreSession()
        first.undoManager.groupsByEvent = false
        #expect(first.recoveredDraft)
        #expect(first.draft == draft)
        try first.edit(0, notation: "fe80::/10", interface: .wifi)
        let second = HallPassModel(backups: store)
        second.restoreSession()
        #expect(second.draft == first.draft)
        #expect(second.snapshot?.xml == baseline.xml)
        #expect(second.discardForClosing())
        #expect(try store.loadRecovery() == nil)
        #expect(!second.isDirty)
    }

    @Test func previewNeverCreatesRecoveryOrAutomaticBackups() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = HallPassModel(mode: .preview, backups: BackupStore(root: directory))
        try model.add("10.0.0.0/8", interfaces: [.wifi])
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test func automaticBackupsRemainPrivateAndReadable() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BackupStore(root: directory)
        let original = NetworkConfiguration(wifi: [], ethernet: ["old", "old"])
        let url = try store.automaticBackup(original)
        #expect(try store.readBackup(at: url) == original)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    private func preview() -> HallPassModel {
        let model = HallPassModel(mode: .preview)
        model.undoManager.groupsByEvent = false
        return model
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("HallPassModelTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
