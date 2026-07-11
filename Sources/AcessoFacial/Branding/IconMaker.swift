import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Gera o ícone do app (1024×1024 PNG): um escudo com rosto estilizado sobre
/// gradiente verde-esmeralda → azul. Nativo (CoreGraphics), sem assets externos.
enum IconMaker {
    static func write(to path: String) {
        let S = 1024
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { print("✗ contexto falhou"); return }

        let sz = CGFloat(S)
        func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
            CGColor(red: r, green: g, blue: b, alpha: a)
        }
        let center = CGPoint(x: sz/2, y: sz/2)

        // Fundo arredondado com gradiente
        let bg = CGPath(roundedRect: CGRect(x: 0, y: 0, width: sz, height: sz),
                        cornerWidth: sz * 0.2237, cornerHeight: sz * 0.2237, transform: nil)
        ctx.saveGState(); ctx.addPath(bg); ctx.clip()
        if let g = CGGradient(colorsSpace: cs,
            colors: [rgb(0.09, 0.14, 0.12), rgb(0.03, 0.05, 0.06)] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: sz), end: CGPoint(x: 0, y: 0), options: [])
        }
        if let glow = CGGradient(colorsSpace: cs,
            colors: [rgb(0.12, 0.77, 0.48, 0.35), rgb(0.12, 0.77, 0.48, 0)] as CFArray, locations: [0, 1]) {
            ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: sz * 0.5, options: [])
        }
        ctx.restoreGState()

        // Escudo
        let shieldW = sz * 0.52, shieldTop = sz * 0.22, shieldBottom = sz * 0.80
        let shield = CGMutablePath()
        shield.move(to: CGPoint(x: center.x, y: shieldTop))
        shield.addCurve(to: CGPoint(x: center.x + shieldW/2, y: shieldTop + shieldW * 0.22),
                        control1: CGPoint(x: center.x + shieldW * 0.18, y: shieldTop),
                        control2: CGPoint(x: center.x + shieldW/2, y: shieldTop + shieldW * 0.06))
        shield.addLine(to: CGPoint(x: center.x + shieldW/2, y: shieldTop + shieldW * 0.55))
        shield.addCurve(to: CGPoint(x: center.x, y: shieldBottom),
                        control1: CGPoint(x: center.x + shieldW/2, y: shieldTop + shieldW * 0.95),
                        control2: CGPoint(x: center.x + shieldW * 0.22, y: shieldBottom - shieldW * 0.14))
        shield.addCurve(to: CGPoint(x: center.x - shieldW/2, y: shieldTop + shieldW * 0.55),
                        control1: CGPoint(x: center.x - shieldW * 0.22, y: shieldBottom - shieldW * 0.14),
                        control2: CGPoint(x: center.x - shieldW/2, y: shieldTop + shieldW * 0.95))
        shield.addLine(to: CGPoint(x: center.x - shieldW/2, y: shieldTop + shieldW * 0.22))
        shield.addCurve(to: CGPoint(x: center.x, y: shieldTop),
                        control1: CGPoint(x: center.x - shieldW/2, y: shieldTop + shieldW * 0.06),
                        control2: CGPoint(x: center.x - shieldW * 0.18, y: shieldTop))
        shield.closeSubpath()

        ctx.saveGState()
        ctx.addPath(shield); ctx.clip()
        if let g = CGGradient(colorsSpace: cs,
            colors: [rgb(0.18, 0.83, 0.58), rgb(0.12, 0.66, 0.48), rgb(0.11, 0.46, 0.74)] as CFArray,
            locations: [0, 0.55, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: center.x, y: shieldBottom),
                                   end: CGPoint(x: center.x, y: shieldTop), options: [])
        }
        ctx.restoreGState()
        ctx.setStrokeColor(rgb(1, 1, 1, 0.18))
        ctx.setLineWidth(sz * 0.006)
        ctx.addPath(shield); ctx.strokePath()

        // Rosto estilizado (contorno de scanner facial: canto quadrado nos 4 cantos + óvalo central)
        let faceW = shieldW * 0.42
        let faceRect = CGRect(x: center.x - faceW/2, y: center.y - faceW*0.62 - shieldW*0.02,
                              width: faceW, height: faceW * 1.24)
        ctx.setStrokeColor(rgb(1, 1, 1, 0.92))
        ctx.setLineWidth(sz * 0.014)
        ctx.addPath(CGPath(ellipseIn: faceRect, transform: nil))
        ctx.strokePath()

        // cantos de "scanner" (top-left, top-right, bottom-left, bottom-right)
        let cornerLen = sz * 0.07
        let pad = sz * 0.03
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: faceRect.minX - pad, y: faceRect.maxY + pad), 1, -1),
            (CGPoint(x: faceRect.maxX + pad, y: faceRect.maxY + pad), -1, -1),
            (CGPoint(x: faceRect.minX - pad, y: faceRect.minY - pad), 1, 1),
            (CGPoint(x: faceRect.maxX + pad, y: faceRect.minY - pad), -1, 1),
        ]
        ctx.setLineWidth(sz * 0.02)
        ctx.setLineCap(.round)
        for (p, dx, dy) in corners {
            ctx.move(to: CGPoint(x: p.x, y: p.y))
            ctx.addLine(to: CGPoint(x: p.x + cornerLen * dx, y: p.y))
            ctx.move(to: CGPoint(x: p.x, y: p.y))
            ctx.addLine(to: CGPoint(x: p.x, y: p.y + cornerLen * dy))
            ctx.strokePath()
        }

        // check mark abaixo do rosto
        ctx.setStrokeColor(rgb(1, 1, 1, 0.95))
        ctx.setLineWidth(sz * 0.026)
        ctx.setLineCap(.round); ctx.setLineJoin(.round)
        let checkY = shieldTop + shieldW * 0.06
        ctx.move(to: CGPoint(x: center.x - sz*0.05, y: checkY))
        ctx.addLine(to: CGPoint(x: center.x - sz*0.012, y: checkY - sz*0.035))
        ctx.addLine(to: CGPoint(x: center.x + sz*0.06, y: checkY + sz*0.03))
        ctx.strokePath()

        guard let img = ctx.makeImage() else { print("✗ imagem falhou"); return }
        let url = URL(fileURLWithPath: path)
        guard let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { print("✗ destino falhou"); return }
        CGImageDestinationAddImage(dst, img, nil)
        if CGImageDestinationFinalize(dst) {
            print("✓ Ícone gerado: \(path)")
        } else {
            print("✗ falha ao salvar ícone")
        }
    }
}
