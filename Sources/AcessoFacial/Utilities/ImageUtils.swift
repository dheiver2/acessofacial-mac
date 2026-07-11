import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation
import AppKit

enum ImageUtils {
    /// Codifica um CGImage como JPEG, redimensionando o lado maior para
    /// `maxDimension` (miniaturas leves para o banco de dados local).
    static func jpegThumbnail(_ image: CGImage, maxDimension: CGFloat = 220, quality: CGFloat = 0.72) -> Data? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let scale = min(1, maxDimension / max(w, h))
        let targetW = max(1, Int(w * scale)), targetH = max(1, Int(h * scale))

        guard let ctx = CGContext(data: nil, width: targetW, height: targetH,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))
        guard let scaled = ctx.makeImage() else { return nil }

        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, scaled, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    static func nsImage(from jpeg: Data?) -> NSImage? {
        guard let jpeg else { return nil }
        return NSImage(data: jpeg)
    }
}
