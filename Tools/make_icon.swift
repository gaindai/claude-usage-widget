import AppKit

// Erzeugt das 1024×1024-Master-Icon: gaind-Gradient-Squircle + weißer Gauge-Ring.
// Aufruf: swift make_icon.swift <output.png>

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let size = 1024.0

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("rep") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func c(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// macOS-Icon-Grid: Motiv 824×824 mit 100px Padding, continuous-ähnlicher Radius.
let pad = 100.0, side = size - 2 * pad, radius = side * 0.225
let squircle = NSBezierPath(roundedRect: NSRect(x: pad, y: pad, width: side, height: side),
                            xRadius: radius, yRadius: radius)

// gaind-Signet-Gradient: Cyan → Deep Blue → Lila → Magenta, diagonal.
let gradient = NSGradient(colors: [c(0x6EAAF0), c(0x0C4AB2), c(0x5748D4), c(0xA945F8)],
                          atLocations: [0.0, 0.38, 0.66, 1.0], colorSpace: .sRGB)!
gradient.draw(in: squircle, angle: -45)

// Gauge-Ring (wie das Widget): 270°-Bogen, Lücke unten, runde Enden, weiß.
let center = NSPoint(x: size / 2, y: size / 2)
let ring = NSBezierPath()
ring.appendArc(withCenter: center, radius: 232, startAngle: -45, endAngle: 225, clockwise: false)
ring.lineWidth = 78
ring.lineCapStyle = .round
NSColor.white.setStroke()
ring.stroke()

// Kleiner Indikatorpunkt am Bogenanfang (unten-rechts) — wie der Gauge-Marker.
let a = -45.0 * .pi / 180
let dot = NSBezierPath(ovalIn: NSRect(
    x: center.x + 232 * cos(a) - 30, y: center.y + 232 * sin(a) - 30, width: 60, height: 60))
NSColor.white.setFill()
dot.fill()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
