#!/usr/bin/env swift
// Renders AppIcon.appiconset from a single Core Graphics drawing so the icon
// is reproducible from source rather than a binary blob in the repo.
// Usage: swift Tools/makeicon.swift Resources/Assets.xcassets/AppIcon.appiconset

import AppKit

let outputDirectory = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "Resources/Assets.xcassets/AppIcon.appiconset")

try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else { return image }
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // macOS icons sit inset inside the canvas with a squircle-ish corner.
    let inset = size * 0.09
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.width * 0.2237)

    context.saveGState()
    path.addClip()
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.24, green: 0.53, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.11, green: 0.29, blue: 0.78, alpha: 1),
    ])
    gradient?.draw(in: rect, angle: -90)
    context.restoreGState()

    let symbolSide = rect.width * 0.56
    let configuration = NSImage.SymbolConfiguration(pointSize: symbolSide, weight: .semibold)
    guard let symbol = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) else { return image }

    let white = NSImage(size: symbol.size, flipped: false) { bounds in
        symbol.draw(in: bounds)
        NSColor.white.set()
        bounds.fill(using: .sourceAtop)
        return true
    }

    let target = CGRect(
        x: rect.midX - white.size.width / 2,
        y: rect.midY - white.size.height / 2,
        width: white.size.width,
        height: white.size.height
    )
    white.draw(in: target)
    return image
}

func writePNG(_ image: NSImage, pixels: Int, name: String) {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()

    let url = outputDirectory.appendingPathComponent(name)
    try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
    print("wrote \(name) (\(pixels)px)")
}

// (point size, scale) pairs required for a macOS app icon.
let variants: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]

var entries: [String] = []
for (points, scale) in variants {
    let pixels = points * scale
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    writePNG(drawIcon(size: CGFloat(pixels)), pixels: pixels, name: name)
    entries.append("""
        {
          "size" : "\(points)x\(points)",
          "idiom" : "mac",
          "filename" : "\(name)",
          "scale" : "\(scale)x"
        }
    """)
}

let contents = """
{
  "images" : [
\(entries.joined(separator: ",\n"))
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
"""
try? contents.write(to: outputDirectory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("wrote Contents.json")
