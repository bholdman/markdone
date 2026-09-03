import AppKit
import CoreGraphics

// Usage: maketemplate <source.png> <out1x.png> <out2x.png>
let args = CommandLine.arguments
guard args.count == 4 else { fputs("need 3 args\n", stderr); exit(1) }
let srcPath = args[1]

guard let srcImage = NSImage(contentsOfFile: srcPath),
      let cg = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("cannot load source\n", stderr); exit(1)
}

let w = cg.width, h = cg.height
let cs = CGColorSpaceCreateDeviceRGB()
let bytesPerRow = w * 4
var pixels = [UInt8](repeating: 0, count: w * h * 4)
guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: bytesPerRow, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fputs("ctx fail\n", stderr); exit(1)
}
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

// Build a template: alpha = darkness (1 - luminance), color forced to black.
// Track content bounds for trimming.
var minX = w, minY = h, maxX = -1, maxY = -1
for y in 0..<h {
    for x in 0..<w {
        let i = (y * w + x) * 4
        let r = Double(pixels[i]), g = Double(pixels[i+1]), b = Double(pixels[i+2])
        let srcA = Double(pixels[i+3]) / 255.0
        let lum = (0.299*r + 0.587*g + 0.114*b) / 255.0
        // darkness scaled by original alpha (so transparent areas stay transparent)
        let alpha = (1.0 - lum) * srcA
        let a8 = UInt8(max(0, min(255, alpha * 255)))
        pixels[i] = 0; pixels[i+1] = 0; pixels[i+2] = 0; pixels[i+3] = a8
        if a8 > 24 { // content threshold for trim bounds
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
    }
}
guard maxX >= minX, maxY >= minY else { fputs("empty image\n", stderr); exit(1) }

guard let trimmedFull = ctx.makeImage() else { fputs("makeImage fail\n", stderr); exit(1) }
let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
guard let cropped = trimmedFull.cropping(to: cropRect) else { fputs("crop fail\n", stderr); exit(1) }

// Render the cropped glyph centered into a square canvas at the target point size,
// with a little padding, preserving aspect ratio.
func writeTemplate(points: Int, to path: String) {
    let side = points
    let pad = Double(side) * 0.10
    let avail = Double(side) - pad * 2
    let cw = Double(cropped.width), ch = Double(cropped.height)
    let scale = min(avail / cw, avail / ch)
    let dw = cw * scale, dh = ch * scale
    let ox = (Double(side) - dw) / 2, oy = (Double(side) - dh) / 2

    var out = [UInt8](repeating: 0, count: side * side * 4)
    guard let octx = CGContext(data: &out, width: side, height: side, bitsPerComponent: 8,
                               bytesPerRow: side * 4, space: cs,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    octx.interpolationQuality = .high
    octx.draw(cropped, in: CGRect(x: ox, y: oy, width: dw, height: dh))
    guard let img = octx.makeImage() else { return }
    let rep = NSBitmapImageRep(cgImage: img)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(side)px)")
}

writeTemplate(points: 18, to: args[2])  // 1x
writeTemplate(points: 36, to: args[3])  // 2x
