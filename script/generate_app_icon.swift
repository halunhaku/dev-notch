import AppKit
import Foundation

let fileManager = FileManager.default
let scriptDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let projectDirectory = scriptDirectory.deletingLastPathComponent()
let sourceURL = scriptDirectory
    .appendingPathComponent("icon/AppIcon_1024.png")
let outputURL = projectDirectory
    .appendingPathComponent("DevNotch/Resources/AppIcon.icns")

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("Unable to load \(sourceURL.path)")
}

func renderPNG(from sourceImage: NSImage, size: Int) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ),
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to create \(size)x\(size) icon representation")
    }

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    bitmap.size = bounds.size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    graphicsContext.imageInterpolation = .high
    NSColor.clear.setFill()
    bounds.fill()
    sourceImage.draw(
        in: bounds,
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .sourceOver,
        fraction: 1
    )
    graphicsContext.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode \(size)x\(size) icon representation")
    }
    return data
}

let iconFiles: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("DevNotch-\(UUID().uuidString).iconset")
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconsetURL) }

var renderedPNGs: [Int: Data] = [:]
for iconFile in iconFiles {
    let data: Data
    if let rendered = renderedPNGs[iconFile.pixels] {
        data = rendered
    } else {
        let rendered = renderPNG(from: sourceImage, size: iconFile.pixels)
        renderedPNGs[iconFile.pixels] = rendered
        data = rendered
    }
    try data.write(to: iconsetURL.appendingPathComponent(iconFile.name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(iconutil.terminationStatus)")
}

print("Generated \(outputURL.path) from \(sourceURL.lastPathComponent)")
