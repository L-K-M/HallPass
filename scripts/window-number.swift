import CoreGraphics
import Darwin
import Foundation

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(EXIT_FAILURE)
}

guard CommandLine.arguments.count == 2, let pid = Int32(CommandLine.arguments[1]) else {
    fail("Pass the running HallPass process ID.")
}

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let normalLevel = Int(CGWindowLevelForKey(.normalWindow))
let candidates = windows.compactMap { window -> (number: UInt32, area: CGFloat)? in
    guard window[kCGWindowOwnerPID as String] as? Int32 == pid,
          window[kCGWindowLayer as String] as? Int == normalLevel,
          let number = window[kCGWindowNumber as String] as? UInt32,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
    return (number, frame.width * frame.height)
}

guard let window = candidates.max(by: { $0.area < $1.area }) else {
    fail("No visible HallPass window found.")
}
print(window.number)
