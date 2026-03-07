import AppKit
import Foundation

func cropAndRound(sourcePath: String, destPath: String, cornerRatio: CGFloat = 0.225) -> Bool {
    guard let image = NSImage(contentsOfFile: sourcePath),
          let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        print("Failed to load \(sourcePath)")
        return false
    }
    
    let width = bitmap.pixelsWide
    let height = bitmap.pixelsHigh
    
    // Find bounding box of non-white pixels
    var minX = width, minY = height, maxX = 0, maxY = 0
    let tolerance: Int = 10 // To account for near-white JPEG artifacts
    
    for y in 0..<height {
        for x in 0..<width {
            guard let color = bitmap.colorAt(x: x, y: y) else { continue }
            // convert to sRGB to be safe
            guard let rgb = color.usingColorSpace(.sRGB) else { continue }
            
            let r = Int(rgb.redComponent * 255)
            let g = Int(rgb.greenComponent * 255)
            let b = Int(rgb.blueComponent * 255)
            
            if r < (255 - tolerance) || g < (255 - tolerance) || b < (255 - tolerance) {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
    }
    
    // Add a tiny bit of padding to avoid cutting off completely
    let padding = 2
    minX = max(0, minX - padding)
    minY = max(0, minY - padding)
    maxX = min(width - 1, maxX + padding)
    maxY = min(height - 1, maxY + padding)
    
    // The visual top of bitmap is y=0.
    // In NSImage drawing coordinates, y=0 is bottom.
    // So the crop rect in standard NSRect coords:
    let cropWidth = CGFloat(maxX - minX)
    let cropHeight = CGFloat(maxY - minY)
    
    // Ensure square aspect ratio based on max dimension
    let maxDim = max(cropWidth, cropHeight)
    let squareRect = NSRect(x: CGFloat(minX) - (maxDim - cropWidth)/2.0,
                            y: CGFloat(height - maxY) - (maxDim - cropHeight)/2.0,
                            width: maxDim, height: maxDim)
                            
    let destSize = NSSize(width: maxDim, height: maxDim)
    let destRect = NSRect(origin: .zero, size: destSize)
    
    let roundedImage = NSImage(size: destSize)
    roundedImage.lockFocus()
    
    let cornerRadius = maxDim * cornerRatio
    let path = NSBezierPath(roundedRect: destRect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()
    
    image.draw(in: destRect, from: squareRect, operation: .sourceOver, fraction: 1.0)
    
    roundedImage.unlockFocus()
    
    guard let outTiff = roundedImage.tiffRepresentation,
          let outBitmap = NSBitmapImageRep(data: outTiff),
          let pngData = outBitmap.representation(using: .png, properties: [:]) else {
        return false
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: destPath))
        return true
    } catch {
        return false
    }
}

let args = CommandLine.arguments
if args.count < 3 { exit(1) }
let input = args[1]
let output = args[2]

if cropAndRound(sourcePath: input, destPath: output) {
    print("Cropped and rounded: \(output)")
    exit(0)
} else {
    print("Failed")
    exit(1)
}
