import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct IconRenderer {
    let size: CGFloat
    let scale: CGFloat

    init(pixels: Int) {
        self.size = CGFloat(pixels)
        self.scale = CGFloat(pixels) / 1024.0
    }

    func render(to url: URL) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size),
            pixelsHigh: Int(size),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else {
            throw NSError(domain: "TodoLiteIcon", code: 1)
        }

        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        draw()
        NSGraphicsContext.current = previousContext

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard
            let sourceImage = bitmap.cgImage,
            let opaqueContext = CGContext(
                data: nil,
                width: Int(size),
                height: Int(size),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else {
            throw NSError(domain: "TodoLiteIcon", code: 2)
        }

        opaqueContext.draw(sourceImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        guard
            let opaqueImage = opaqueContext.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            throw NSError(domain: "TodoLiteIcon", code: 3)
        }

        CGImageDestinationAddImage(destination, opaqueImage, nil)
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "TodoLiteIcon", code: 4)
        }
    }

    private func draw() {
        let rect = NSRect(x: 0, y: 0, width: size, height: size)

        NSGradient(colors: [
            NSColor(calibratedRed: 0.09, green: 0.63, blue: 0.57, alpha: 1),
            NSColor(calibratedRed: 0.13, green: 0.45, blue: 0.80, alpha: 1),
            NSColor(calibratedRed: 0.16, green: 0.25, blue: 0.55, alpha: 1)
        ])?.draw(in: rect, angle: 128)

        drawGlow()
        drawBoardColumns()
        drawTaskCard()
        drawCheckmark()
    }

    private func drawGlow() {
        NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.33, alpha: 0.28).setFill()
        NSBezierPath(ovalIn: NSRect(x: 620 * scale, y: 690 * scale, width: 270 * scale, height: 270 * scale)).fill()

        NSColor(calibratedRed: 0.62, green: 0.97, blue: 0.88, alpha: 0.22).setFill()
        NSBezierPath(ovalIn: NSRect(x: 95 * scale, y: 110 * scale, width: 410 * scale, height: 410 * scale)).fill()
    }

    private func drawBoardColumns() {
        let columnColor = NSColor.white.withAlphaComponent(0.20)
        let accentColor = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 0.9)

        for (index, height) in [300, 430, 245].enumerated() {
            let x = CGFloat(150 + index * 150) * scale
            let column = NSRect(x: x, y: 210 * scale, width: 74 * scale, height: CGFloat(height) * scale)
            columnColor.setFill()
            NSBezierPath(roundedRect: column, xRadius: 28 * scale, yRadius: 28 * scale).fill()
        }

        accentColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 300 * scale, y: 560 * scale, width: 74 * scale, height: 80 * scale), xRadius: 28 * scale, yRadius: 28 * scale).fill()
    }

    private func drawTaskCard() {
        NSGraphicsContext.current?.saveGraphicsState()

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.23)
        shadow.shadowOffset = NSSize(width: 0, height: -24 * scale)
        shadow.shadowBlurRadius = 42 * scale
        shadow.set()

        let card = NSRect(x: 260 * scale, y: 250 * scale, width: 560 * scale, height: 430 * scale)
        let path = NSBezierPath(roundedRect: card, xRadius: 72 * scale, yRadius: 72 * scale)
        NSColor(calibratedRed: 0.98, green: 0.99, blue: 0.98, alpha: 1).setFill()
        path.fill()

        NSGraphicsContext.current?.restoreGraphicsState()

        NSColor(calibratedRed: 0.08, green: 0.17, blue: 0.25, alpha: 0.12).setFill()
        NSBezierPath(roundedRect: NSRect(x: 360 * scale, y: 540 * scale, width: 340 * scale, height: 36 * scale), xRadius: 18 * scale, yRadius: 18 * scale).fill()
        NSBezierPath(roundedRect: NSRect(x: 360 * scale, y: 470 * scale, width: 275 * scale, height: 32 * scale), xRadius: 16 * scale, yRadius: 16 * scale).fill()
        NSBezierPath(roundedRect: NSRect(x: 360 * scale, y: 400 * scale, width: 210 * scale, height: 32 * scale), xRadius: 16 * scale, yRadius: 16 * scale).fill()

        NSColor(calibratedRed: 0.10, green: 0.62, blue: 0.55, alpha: 0.16).setFill()
        NSBezierPath(roundedRect: NSRect(x: 610 * scale, y: 340 * scale, width: 112 * scale, height: 54 * scale), xRadius: 27 * scale, yRadius: 27 * scale).fill()
    }

    private func drawCheckmark() {
        let circle = NSRect(x: 184 * scale, y: 394 * scale, width: 245 * scale, height: 245 * scale)
        NSColor(calibratedRed: 0.98, green: 0.75, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(ovalIn: circle).fill()

        let mark = NSBezierPath()
        mark.move(to: NSPoint(x: 250 * scale, y: 512 * scale))
        mark.line(to: NSPoint(x: 310 * scale, y: 452 * scale))
        mark.line(to: NSPoint(x: 394 * scale, y: 570 * scale))
        mark.lineCapStyle = .round
        mark.lineJoinStyle = .round
        mark.lineWidth = 44 * scale
        NSColor.white.setStroke()
        mark.stroke()
    }
}

let output = URL(fileURLWithPath: "TodoLite/Assets.xcassets/AppIcon.appiconset")
let sizes = [16, 20, 29, 32, 40, 58, 60, 64, 76, 80, 87, 120, 128, 152, 167, 180, 256, 512, 1024]

for pixels in sizes {
    let file = output.appendingPathComponent("AppIcon-\(pixels).png")
    try IconRenderer(pixels: pixels).render(to: file)
}
