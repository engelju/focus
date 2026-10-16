// Draws the app icon and writes a 1024×1024 PNG.
// Usage: swift Scripts/make-icon.swift /path/to/icon.png
import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let side: CGFloat = 1024

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                 pixelsWide: Int(side),
                                 pixelsHigh: Int(side),
                                 bitsPerSample: 8,
                                 samplesPerPixel: 4,
                                 hasAlpha: true,
                                 isPlanar: false,
                                 colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0,
                                 bitsPerPixel: 0) else {
    fatalError("could not create bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Rounded-square plate with a warm gradient.
let margin = side * 0.085
let plate = NSRect(x: margin, y: margin, width: side - 2 * margin, height: side - 2 * margin)
let platePath = NSBezierPath(roundedRect: plate,
                             xRadius: plate.width * 0.235,
                             yRadius: plate.width * 0.235)
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.98, green: 0.55, blue: 0.25, alpha: 1),
    NSColor(srgbRed: 0.92, green: 0.30, blue: 0.22, alpha: 1),
])
gradient?.draw(in: platePath, angle: -60)

// Progress ring: three quarters filled, like a session in progress.
let center = NSPoint(x: plate.midX, y: plate.midY)
let radius = plate.width * 0.29
let lineWidth = plate.width * 0.085

let track = NSBezierPath()
track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
track.lineWidth = lineWidth
NSColor.white.withAlphaComponent(0.3).setStroke()
track.stroke()

let arc = NSBezierPath()
arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: -180, clockwise: true)
arc.lineWidth = lineWidth
arc.lineCapStyle = .round
NSColor.white.setStroke()
arc.stroke()

// Centre dot.
let dot = NSBezierPath(ovalIn: NSRect(x: center.x - lineWidth * 0.42,
                                      y: center.y - lineWidth * 0.42,
                                      width: lineWidth * 0.84,
                                      height: lineWidth * 0.84))
NSColor.white.setFill()
dot.fill()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode png")
}
try data.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
