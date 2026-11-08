// Draws Tonic's app icon (1024×1024) so it can be regenerated or tweaked by anyone.
//
//   swift scripts/make-icon.swift Tonic/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
// Design: a teal-to-indigo gradient, a white score ring about three-quarters full,
// and a leaf rising through the middle (growth + progress).

import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

guard let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("Couldn't create drawing context") }

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// Background gradient (iOS rounds the corners itself).
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
    colors: [color(0.18, 0.80, 0.66), color(0.12, 0.56, 0.62), color(0.27, 0.27, 0.70)] as CFArray,
    locations: [0, 0.5, 1]
)!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

let center = CGPoint(x: size / 2, y: size / 2)
let radius: CGFloat = 330
let lineWidth: CGFloat = 92

// Ring track.
ctx.setLineWidth(lineWidth)
ctx.setStrokeColor(color(1, 1, 1, 0.22))
ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

// Ring progress: from the top, clockwise, about 75%.
ctx.setLineCap(.round)
ctx.setStrokeColor(color(1, 1, 1))
ctx.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 1.5, clockwise: true)
ctx.strokePath()

// Leaf: two arcs meeting at a point, tilted up and to the right.
ctx.saveGState()
ctx.translateBy(x: center.x, y: center.y - 10)
ctx.rotate(by: -.pi / 4)
let leafLength: CGFloat = 430
let leafWidth: CGFloat = 150
let half = leafLength / 2
let leaf = CGMutablePath()
leaf.move(to: CGPoint(x: 0, y: -half))
leaf.addCurve(to: CGPoint(x: 0, y: half),
              control1: CGPoint(x: leafWidth * 1.25, y: -half * 0.55),
              control2: CGPoint(x: leafWidth * 0.9, y: half * 0.6))
leaf.addCurve(to: CGPoint(x: 0, y: -half),
              control1: CGPoint(x: -leafWidth * 0.9, y: half * 0.6),
              control2: CGPoint(x: -leafWidth * 1.25, y: -half * 0.55))
ctx.addPath(leaf)
ctx.setFillColor(color(1, 1, 1))
ctx.fillPath()

// Leaf vein.
ctx.setStrokeColor(color(0.12, 0.56, 0.62, 0.55))
ctx.setLineWidth(14)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 0, y: -half - 30))
ctx.addLine(to: CGPoint(x: 0, y: half - 60))
ctx.strokePath()
ctx.restoreGState()

guard let image = ctx.makeImage(),
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
else { fatalError("Couldn't render icon") }
try! data.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
