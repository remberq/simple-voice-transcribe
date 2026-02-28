import AppKit
import Foundation

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    exit(1)
}

// Clear to transparent
ctx.clear(CGRect(origin: .zero, size: size))

// --- 1. Draw Mac squircle background ---
NSGraphicsContext.saveGraphicsState()

// Big Sur standard metrics for 1024: an 824x824 squircle centered.
// The true radius for a pure rounded rect matching squircle closely is 185.6.
let squircleRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 185.6, yRadius: 185.6)

// Add drop shadow to make it pop like a real macOS app icon
let shadow = NSShadow()
shadow.shadowBlurRadius = 20
shadow.shadowOffset = NSSize(width: 0, height: -15)
shadow.shadowColor = NSColor(white: 0, alpha: 0.25)
shadow.set()

NSColor.white.set()
squirclePath.fill()

// Restore to remove shadow for drawing the microphone
NSGraphicsContext.restoreGraphicsState()

// --- 2. Draw Microphone Symbol ---
let pointSize: CGFloat = 450 // Scale relative to the 824 squircle
let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)

// Using "mic.fill" inside the white background means the body of the mic is dark blue.
if let micImage = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    
    // Tint color = dark blue #000936
    let darkColor = NSColor(red: 0, green: 9/255.0, blue: 54/255.0, alpha: 1.0)
    
    func tint(image: NSImage, color: NSColor) -> NSImage {
        let tinted = image.copy() as! NSImage
        tinted.isTemplate = false
        tinted.lockFocus()
        color.set()
        NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        return tinted
    }
    
    // Size and center the symbol
    let tintedMic = tint(image: micImage, color: darkColor)
    let micSize = tintedMic.size
    let micRect = NSRect(
        x: squircleRect.minX + (squircleRect.width - micSize.width) / 2.0,
        y: squircleRect.minY + (squircleRect.height - micSize.height) / 2.0,
        width: micSize.width,
        height: micSize.height
    )
    
    tintedMic.draw(in: micRect)
}

image.unlockFocus()

if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    let url = URL(fileURLWithPath: "Resources/AppIcon_transparent.png")
    try! pngData.write(to: url)
    print("Saved to Resources/AppIcon_transparent.png")
}
