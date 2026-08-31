#!/usr/bin/env swift
// Renders Vellbar.icns from code.
//   swift Scripts/make-icon.swift
//
// Design: a menu bar with icons, and a chevron folding them away.

import AppKit
import CoreGraphics
import Foundation

let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources")
let iconset = outputDir.appendingPathComponent("Vellbar.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

func draw(size: CGFloat) -> CGImage? {
    guard let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    ctx.scaleBy(x: size / 1024, y: size / 1024)

    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil))
    ctx.clip()
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: [hex(0x2E63A8), hex(0x14315C)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: plate.maxY),
                           end: CGPoint(x: 0, y: plate.minY), options: [])
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: plate.insetBy(dx: 6, dy: 6),
                       cornerWidth: 180, cornerHeight: 180, transform: nil))
    ctx.setStrokeColor(hex(0xFFFFFF, 0.16)); ctx.setLineWidth(6); ctx.strokePath()
    ctx.restoreGState()

    // A row of menu bar icons, with the leftmost pair dimmed — being folded away.
    let y: CGFloat = 470
    let dot: CGFloat = 58
    let gap: CGFloat = 34
    let opacities: [CGFloat] = [0.28, 0.45, 0.92, 0.92]
    var x: CGFloat = 300
    for (i, alpha) in opacities.enumerated() {
        ctx.setFillColor(i >= 2 ? hex(0xFFFFFF, alpha) : hex(0xFFFFFF, alpha))
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: dot, height: dot),
                           cornerWidth: 16, cornerHeight: 16, transform: nil))
        ctx.fillPath()
        x += dot + gap
    }

    // The chevron that does the folding, in brass.
    ctx.setStrokeColor(hex(0xE0B25C))
    ctx.setLineWidth(46)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 268, y: 620))
    ctx.addLine(to: CGPoint(x: 196, y: 499))
    ctx.addLine(to: CGPoint(x: 268, y: 378))
    ctx.strokePath()

    return ctx.makeImage()
}

func write(_ image: CGImage, to url: URL) {
    guard let d = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { return }
    CGImageDestinationAddImage(d, image, nil); CGImageDestinationFinalize(d)
}

let variants: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256),
    ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in variants {
    guard let img = draw(size: size) else { print("failed at \(name)"); exit(1) }
    write(img, to: iconset.appendingPathComponent("\(name).png"))
}
if let big = draw(size: 1024) { write(big, to: outputDir.appendingPathComponent("icon-preview.png")) }

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path,
                  "-o", outputDir.appendingPathComponent("Vellbar.icns").path]
try task.run(); task.waitUntilExit()
print(task.terminationStatus == 0 ? "wrote Resources/Vellbar.icns" : "iconutil failed")
