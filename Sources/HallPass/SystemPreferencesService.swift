import Foundation
import HallPassCore

enum PreferencesServiceError: LocalizedError {
    case cancelled, conflict, restored, rollbackFailed, commandFailed(String), verificationFailed

    var errorDescription: String? {
        switch self {
        case .cancelled: "Der Administrator-Dialog wurde abgebrochen."
        case .conflict: "Die Systemeinstellungen wurden zwischenzeitlich geändert. Bitte erneut laden und deine Änderungen noch einmal vornehmen."
        case .restored: "Das Speichern ist fehlgeschlagen. Die vorherigen Einstellungen wurden wiederhergestellt."
        case .rollbackFailed: "Die Änderung konnte nicht vollständig zurückgenommen werden. Lade die Systemeinstellungen neu und stelle bei Bedarf das automatische Backup wieder her."
        case .commandFailed(let detail): "macOS konnte den Befehl nicht ausführen.\n\(detail)"
        case .verificationFailed: "Die gespeicherten Werte stimmen nicht mit der Vorschau überein. Bitte neu laden. Das automatische Backup bleibt verfügbar."
        }
    }
}

protocol PreferencesServicing: Sendable {
    func load() async throws -> PreferencesSnapshot
    func save(_ plan: PreferencePlan) async throws -> PreferencesSnapshot
}

actor SystemPreferencesService: PreferencesServicing {
    func load() throws -> PreferencesSnapshot {
        let xml = try authorized(PreferencePlan.readCommand, prompt: "HallPass möchte die lokalen Netzfreigaben lesen.")
        return try PreferencesSnapshot(xml: xml)
    }

    func save(_ plan: PreferencePlan) throws -> PreferencesSnapshot {
        let xml = try authorized(plan.shellScript(), prompt: "HallPass möchte die angezeigten Netzfreigaben speichern.")
        let result = try PreferencesSnapshot(xml: xml)
        guard result.configuration == plan.desired else { throw PreferencesServiceError.verificationFailed }
        return result
    }

    private func authorized(_ command: String, prompt: String) throws -> String {
        let source = "do shell script \(PreferencePlan.appleScriptString(command)) with prompt \(PreferencePlan.appleScriptString(prompt)) with administrator privileges without altering line endings"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output
        try process.run()
        input.fileHandleForWriting.write(Data(source.utf8))
        try input.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let result = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            if result.contains("(-128)") { throw PreferencesServiceError.cancelled }
            if result.contains("HALLPASS_CONFLICT") { throw PreferencesServiceError.conflict }
            if result.contains("HALLPASS_ROLLBACK_FAILED") { throw PreferencesServiceError.rollbackFailed }
            if result.contains("HALLPASS_WRITE_FAILED_RESTORED") { throw PreferencesServiceError.restored }
            throw PreferencesServiceError.commandFailed(String(result.prefix(1600)))
        }
        return result
    }
}
