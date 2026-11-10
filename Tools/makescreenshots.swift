#!/usr/bin/env swift
// Composites App Store screenshots at 2560x1600 (a size Apple accepts for Mac).
// Usage: swift Tools/makescreenshots.swift <input.png> <output.png> <headline> <subhead>

import AppKit

guard CommandLine.arguments.count >= 5 else {
    print("usage: makescreenshots.swift <input.png> <output.png> <headline> <subhead>")
    exit(1)
}
let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let headline = CommandLine.arguments[3]
let subhead = CommandLine.arguments[4]
// Corner radius of the composited card. Match it to the source window's own
// radius after scaling, or white notches show at the corners.
let cornerRadius = CommandLine.arguments.count > 5 ? CGFloat(Double(CommandLine.arguments[5]) ?? 26) : 26

let canvas = CGSize(width: 2560, height: 1600)

guard let shot = NSImage(contentsOf: inputURL),
      let rep = NSImageRep(contentsOf: inputURL) else {
    print("could not read \(inputURL.path)")
    exit(1)
}
// Retina captures carry 144 DPI metadata, which makes NSImage report half the
// real pixel count and silently renders the capture at half size.
shot.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
bitmap.size = NSSize(width: canvas.width, height: canvas.height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let context = NSGraphicsContext.current!.cgContext

let full = CGRect(origin: .zero, size: canvas)
NSGradient(colors: [
    NSColor(srgbRed: 0.91, green: 0.94, blue: 0.99, alpha: 1),
    NSColor(srgbRed: 0.76, green: 0.84, blue: 0.97, alpha: 1),
])?.draw(in: full, angle: -90)

// Text sits at the top; AppKit's origin is bottom-left, hence the subtraction.
let headlineStyle = NSMutableParagraphStyle()
headlineStyle.alignment = .center
let headlineAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 104, weight: .bold),
    .foregroundColor: NSColor(srgbRed: 0.06, green: 0.13, blue: 0.30, alpha: 1),
    .paragraphStyle: headlineStyle,
]
let subheadAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 52, weight: .regular),
    .foregroundColor: NSColor(srgbRed: 0.20, green: 0.30, blue: 0.48, alpha: 1),
    .paragraphStyle: headlineStyle,
]

let headlineRect = CGRect(x: 160, y: canvas.height - 250, width: canvas.width - 320, height: 130)
headline.draw(in: headlineRect, withAttributes: headlineAttributes)
let subheadRect = CGRect(x: 160, y: canvas.height - 340, width: canvas.width - 320, height: 80)
subhead.draw(in: subheadRect, withAttributes: subheadAttributes)

// Fit the capture into the remaining space without upscaling past 2x.
let available = CGSize(width: canvas.width - 500, height: canvas.height - 560)
let scale = min(available.width / shot.size.width, available.height / shot.size.height, 2.6)
let drawn = CGSize(width: shot.size.width * scale, height: shot.size.height * scale)
let target = CGRect(
    x: (canvas.width - drawn.width) / 2,
    y: (canvas.height - drawn.height) / 2 - 110,
    width: drawn.width,
    height: drawn.height
)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 60,
                  color: NSColor(srgbRed: 0.05, green: 0.12, blue: 0.30, alpha: 0.32).cgColor)
let clip = NSBezierPath(roundedRect: target, xRadius: cornerRadius, yRadius: cornerRadius)
NSColor.white.setFill()
clip.fill()
context.restoreGState()

context.saveGState()
clip.addClip()
shot.draw(in: target)
context.restoreGState()

NSGraphicsContext.restoreGraphicsState()

try? bitmap.representation(using: .png, properties: [:])?.write(to: outputURL)
print("wrote \(outputURL.lastPathComponent) (\(Int(canvas.width))x\(Int(canvas.height)))")
