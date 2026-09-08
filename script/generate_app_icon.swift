import AppKit
import CoreGraphics

func createIcon() -> NSImage {
    let canvasSize: CGFloat = 1024
    let tileSize: CGFloat = 824
    let tileX: CGFloat = (canvasSize - tileSize) / 2 // 100
    let tileY: CGFloat = (canvasSize - tileSize) / 2 // 100
    let cornerRadius: CGFloat = 185

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapContext = CGContext(
        data: nil,
        width: Int(canvasSize),
        height: Int(canvasSize),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    let ctx = bitmapContext

    // AppKit coordinate system: origin bottom-left
    let tileRect = CGRect(x: tileX, y: tileY, width: tileSize, height: tileSize)
    let squirclePath = CGPath(
        roundedRect: tileRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    // 1. Multi-Layer Drop Shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -22),
        blur: 36,
        color: NSColor.black.withAlphaComponent(0.38).cgColor
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -8),
        blur: 14,
        color: NSColor.black.withAlphaComponent(0.28).cgColor
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Base Squircle Surface with Rich Deep Gradient
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let baseColors = [
        NSColor(red: 0.08, green: 0.11, blue: 0.22, alpha: 1.0).cgColor, // Top: Deep Midnight Blue
        NSColor(red: 0.04, green: 0.06, blue: 0.14, alpha: 1.0).cgColor, // Mid: Dark Navy
        NSColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1.0).cgColor  // Bottom: Obsidian Space Black
    ] as CFArray
    let baseLocations: [CGFloat] = [0.0, 0.45, 1.0]
    let baseGradient = CGGradient(colorsSpace: colorSpace, colors: baseColors, locations: baseLocations)!

    ctx.drawLinearGradient(
        baseGradient,
        start: CGPoint(x: 512, y: tileY + tileSize),
        end: CGPoint(x: 512, y: tileY),
        options: []
    )

    // Subtle Radial Ambient Glow inside the squircle
    let radialColors = [
        NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.16).cgColor,
        NSColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 0.08).cgColor,
        NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0).cgColor
    ] as CFArray
    let radialGrad = CGGradient(colorsSpace: colorSpace, colors: radialColors, locations: [0.0, 0.5, 1.0])!
    ctx.drawRadialGradient(
        radialGrad,
        startCenter: CGPoint(x: 512, y: 560),
        startRadius: 0,
        endCenter: CGPoint(x: 512, y: 560),
        endRadius: 400,
        options: []
    )

    // 3. The Physical MacBook Notch at Top
    let notchWidth: CGFloat = 340
    let notchHeight: CGFloat = 72
    let notchCornerRadius: CGFloat = 22
    let notchX = 512 - notchWidth / 2
    let notchTop = tileY + tileSize
    let notchBottom = notchTop - notchHeight

    let notchPath = CGMutablePath()
    notchPath.move(to: CGPoint(x: notchX, y: notchTop))
    notchPath.addLine(to: CGPoint(x: notchX, y: notchBottom + notchCornerRadius))
    notchPath.addArc(
        tangent1End: CGPoint(x: notchX, y: notchBottom),
        tangent2End: CGPoint(x: notchX + notchCornerRadius, y: notchBottom),
        radius: notchCornerRadius
    )
    notchPath.addLine(to: CGPoint(x: notchX + notchWidth - notchCornerRadius, y: notchBottom))
    notchPath.addArc(
        tangent1End: CGPoint(x: notchX + notchWidth, y: notchBottom),
        tangent2End: CGPoint(x: notchX + notchWidth, y: notchBottom + notchCornerRadius),
        radius: notchCornerRadius
    )
    notchPath.addLine(to: CGPoint(x: notchX + notchWidth, y: notchTop))
    notchPath.closeSubpath()

    // Draw Notch Fill (Pitch Black OLED)
    ctx.saveGState()
    ctx.addPath(notchPath)
    ctx.setFillColor(NSColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1.0).cgColor)
    ctx.fillPath()

    // Notch Bezel Stroke
    ctx.addPath(notchPath)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.12).cgColor)
    ctx.setLineWidth(1.5)
    ctx.strokePath()

    // Camera Lens & Indicator
    let cameraCenter = CGPoint(x: 512, y: notchTop - notchHeight / 2)
    // Outer lens rim
    ctx.addArc(center: cameraCenter, radius: 10, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    ctx.setFillColor(NSColor(red: 0.08, green: 0.1, blue: 0.14, alpha: 1.0).cgColor)
    ctx.fillPath()

    // Inner optical element
    ctx.addArc(center: cameraCenter, radius: 6, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    ctx.setFillColor(NSColor(red: 0.02, green: 0.22, blue: 0.35, alpha: 1.0).cgColor)
    ctx.fillPath()

    // Optical specular pin
    ctx.addArc(center: CGPoint(x: cameraCenter.x - 2, y: cameraCenter.y + 2), radius: 2, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    ctx.setFillColor(NSColor(white: 1.0, alpha: 0.8).cgColor)
    ctx.fillPath()

    // Green indicator LED
    ctx.addArc(center: CGPoint(x: cameraCenter.x + 36, y: cameraCenter.y), radius: 3, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    ctx.setFillColor(NSColor(red: 0.1, green: 0.9, blue: 0.4, alpha: 0.9).cgColor)
    ctx.fillPath()

    ctx.restoreGState() // Done with notch

    // 4. Task Pulse Horizon Glow Arc (under notch curved contour)
    let pulseArc = CGMutablePath()
    pulseArc.move(to: CGPoint(x: notchX - 2, y: notchBottom + notchCornerRadius))
    pulseArc.addArc(
        tangent1End: CGPoint(x: notchX, y: notchBottom),
        tangent2End: CGPoint(x: notchX + notchCornerRadius, y: notchBottom),
        radius: notchCornerRadius
    )
    pulseArc.addLine(to: CGPoint(x: notchX + notchWidth - notchCornerRadius, y: notchBottom))
    pulseArc.addArc(
        tangent1End: CGPoint(x: notchX + notchWidth, y: notchBottom),
        tangent2End: CGPoint(x: notchX + notchWidth, y: notchBottom + notchCornerRadius),
        radius: notchCornerRadius
    )

    // Soft outer neon glow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.85).cgColor)
    ctx.addPath(pulseArc)
    ctx.setStrokeColor(NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.9).cgColor)
    ctx.setLineWidth(5)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // Core electric line
    ctx.saveGState()
    ctx.addPath(pulseArc)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.95).cgColor)
    ctx.setLineWidth(2.5)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // 5. Central Dynamic Island Glass Capsule
    let islandWidth: CGFloat = 460
    let islandHeight: CGFloat = 170
    let islandX = 512 - islandWidth / 2
    let islandY: CGFloat = 430
    let islandRadius: CGFloat = 52
    let islandRect = CGRect(x: islandX, y: islandY, width: islandWidth, height: islandHeight)
    let islandPath = CGPath(roundedRect: islandRect, cornerWidth: islandRadius, cornerHeight: islandRadius, transform: nil)

    // Island drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    ctx.addPath(islandPath)
    ctx.setFillColor(NSColor(red: 0.03, green: 0.05, blue: 0.12, alpha: 0.88).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Island subtle gradient fill
    ctx.saveGState()
    ctx.addPath(islandPath)
    ctx.clip()
    let islandGradColors = [
        NSColor(red: 0.10, green: 0.14, blue: 0.28, alpha: 0.92).cgColor,
        NSColor(red: 0.04, green: 0.07, blue: 0.16, alpha: 0.95).cgColor
    ] as CFArray
    let islandGrad = CGGradient(colorsSpace: colorSpace, colors: islandGradColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(islandGrad, start: CGPoint(x: 512, y: islandY + islandHeight), end: CGPoint(x: 512, y: islandY), options: [])

    // Island glass stroke
    ctx.addPath(islandPath)
    ctx.setStrokeColor(NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.35).cgColor)
    ctx.setLineWidth(2.0)
    ctx.strokePath()
    ctx.restoreGState()

    // 6. Developer Bracket Code Glyph inside Island: < / >
    let glyphY = islandY + islandHeight / 2
    ctx.saveGState()

    // Left Bracket <
    let leftBracket = CGMutablePath()
    leftBracket.move(to: CGPoint(x: 512 - 95, y: glyphY + 36))
    leftBracket.addLine(to: CGPoint(x: 512 - 145, y: glyphY))
    leftBracket.addLine(to: CGPoint(x: 512 - 95, y: glyphY - 36))

    ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 12, color: NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.7).cgColor)
    ctx.addPath(leftBracket)
    ctx.setStrokeColor(NSColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1.0).cgColor)
    ctx.setLineWidth(14)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // Center Energy Slash /
    let centerSlash = CGMutablePath()
    centerSlash.move(to: CGPoint(x: 512 + 22, y: glyphY + 44))
    centerSlash.addLine(to: CGPoint(x: 512 - 22, y: glyphY - 44))

    ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 14, color: NSColor(red: 0.4, green: 0.5, blue: 1.0, alpha: 0.85).cgColor)
    ctx.addPath(centerSlash)
    ctx.setStrokeColor(NSColor(red: 0.55, green: 0.65, blue: 1.0, alpha: 1.0).cgColor)
    ctx.setLineWidth(15)
    ctx.setLineCap(.round)
    ctx.strokePath()

    // Right Bracket >
    let rightBracket = CGMutablePath()
    rightBracket.move(to: CGPoint(x: 512 + 95, y: glyphY + 36))
    rightBracket.addLine(to: CGPoint(x: 512 + 145, y: glyphY))
    rightBracket.addLine(to: CGPoint(x: 512 + 95, y: glyphY - 36))

    ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 12, color: NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.7).cgColor)
    ctx.addPath(rightBracket)
    ctx.setStrokeColor(NSColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1.0).cgColor)
    ctx.setLineWidth(14)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    ctx.restoreGState()

    // 7. Satellite AI Provider Constellation Nodes
    struct Node {
        let center: CGPoint
        let radius: CGFloat
        let color: NSColor
    }
    let nodes = [
        Node(center: CGPoint(x: 512 - 180, y: glyphY), radius: 7, color: NSColor(red: 0.06, green: 0.85, blue: 0.55, alpha: 1.0)), // Codex Emerald
        Node(center: CGPoint(x: 512 + 180, y: glyphY), radius: 7, color: NSColor(red: 0.1, green: 0.75, blue: 0.95, alpha: 1.0)),  // DeepSeek Cyan
        Node(center: CGPoint(x: 512 - 75, y: islandY - 32), radius: 6, color: NSColor(red: 0.96, green: 0.65, blue: 0.15, alpha: 1.0)), // Claude Amber
        Node(center: CGPoint(x: 512 + 75, y: islandY - 32), radius: 6, color: NSColor(red: 0.65, green: 0.45, blue: 0.98, alpha: 1.0))  // Antigravity Purple
    ]

    for node in nodes {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 10, color: node.color.withAlphaComponent(0.8).cgColor)
        ctx.addArc(center: node.center, radius: node.radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        ctx.setFillColor(node.color.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    // 8. Outer Squircle Specular Rim Stroke
    ctx.restoreGState() // restore clip to squircle
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.22).cgColor)
    ctx.setLineWidth(2.0)
    ctx.strokePath()
    ctx.restoreGState()

    let cgImage = ctx.makeImage()!
    return NSImage(cgImage: cgImage, size: NSSize(width: canvasSize, height: canvasSize))
}

let image = createIcon()
guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData),
      let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to export PNG")
}

let outputURL = URL(fileURLWithPath: "AppIcon_1024.png")
try! pngData.write(to: outputURL)
print("SUCCESS: Wrote 1024x1024 AppIcon_1024.png")
