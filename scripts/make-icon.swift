import AppKit
import Foundation

// A vector-drawn ticket mark, rendered at every native macOS icon size.
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let tile = NSBezierPath(roundedRect: NSRect(x: 65, y: 65, width: 894, height: 894), xRadius: 206, yRadius: 206)
        NSGradient(starting: NSColor(calibratedRed: 0.19, green: 0.53, blue: 0.43, alpha: 1),
                   ending: NSColor(calibratedRed: 0.08, green: 0.30, blue: 0.25, alpha: 1))!
            .draw(in: tile, angle: -65)
        context.translateBy(x: 512, y: 512)
        context.rotate(by: .pi / 10)
        let ticket = NSBezierPath(roundedRect: NSRect(x: -290, y: -185, width: 580, height: 370), xRadius: 52, yRadius: 52)
        NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.91, alpha: 1).setFill()
        ticket.fill()
        NSColor(calibratedRed: 0.13, green: 0.41, blue: 0.33, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: -324, y: -38, width: 76, height: 76)).fill()
        NSBezierPath(ovalIn: NSRect(x: 248, y: -38, width: 76, height: 76)).fill()
        let check = NSBezierPath()
        check.move(to: NSPoint(x: -110, y: -4))
        check.line(to: NSPoint(x: -28, y: -80))
        check.line(to: NSPoint(x: 124, y: 84))
        check.lineWidth = 40
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        NSColor(calibratedRed: 0.13, green: 0.43, blue: 0.35, alpha: 1).setStroke()
        check.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(size)x\(size)\(suffix).png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(name))
    }
}
