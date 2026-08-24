import AppKit

let canvas = 1024.0
let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { rect in
    let icon = rect.insetBy(dx: 72, dy: 72)
    let radius = icon.width * 0.223
    let squircle = NSBezierPath(roundedRect: icon, xRadius: radius, yRadius: radius)

    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()

    let background = NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.14, alpha: 1)
    background.setFill()
    squircle.fill()

    let sidebarWidth = icon.width * 0.30
    let sidebar = NSRect(x: icon.minX, y: icon.minY, width: sidebarWidth, height: icon.height)
    NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.22, alpha: 1).setFill()
    sidebar.fill()

    let pillColor = NSColor(calibratedRed: 0.32, green: 0.34, blue: 0.38, alpha: 1)
    let selected = NSColor(calibratedRed: 0.30, green: 0.48, blue: 0.78, alpha: 1)
    let pillInset: CGFloat = 22
    let pillHeight: CGFloat = 70
    let pillGap: CGFloat = 28
    var pillY = icon.maxY - 150
    for index in 0..<3 {
        let pill = NSRect(
            x: sidebar.minX + pillInset,
            y: pillY,
            width: sidebar.width - pillInset * 2,
            height: pillHeight
        )
        (index == 0 ? selected : pillColor).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 16, yRadius: 16).fill()
        pillY -= pillHeight + pillGap
    }

    let caret = NSRect(
        x: icon.minX + sidebarWidth + 64,
        y: icon.midY - 70,
        width: 42,
        height: 140
    )
    NSColor(calibratedRed: 0.96, green: 0.72, blue: 0.22, alpha: 1).setFill()
    NSBezierPath(roundedRect: caret, xRadius: 8, yRadius: 8).fill()

    NSGraphicsContext.current?.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.12).setStroke()
    squircle.lineWidth = 6
    squircle.stroke()
    return true
}

let args = CommandLine.arguments
guard args.count > 1 else {
    fputs("usage: make-icon <png-path>\n", stderr)
    exit(1)
}
let url = URL(fileURLWithPath: args[1])
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode png\n", stderr)
    exit(1)
}
try png.write(to: url)
