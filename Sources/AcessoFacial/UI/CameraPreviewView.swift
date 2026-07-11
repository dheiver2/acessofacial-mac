import SwiftUI
import CoreGraphics

/// Exibe o quadro atual da câmera com overlay de TODOS os rostos detectados,
/// cada um com cor e rótulo conforme a decisão (liberado/negado/bloqueado/…).
struct CameraPreviewView: View {
    let image: CGImage?
    let faces: [FaceResult]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay(overlay(imageSize: CGSize(width: image.width, height: image.height)))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.metering.center.weighted")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundStyle(Brand.faint)
                        Text("Iniciando câmera…").foregroundStyle(Brand.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }

    private func overlay(imageSize: CGSize) -> some View {
        Canvas { ctx, size in
            let scale = min(size.width / imageSize.width, size.height / imageSize.height)
            let offX = (size.width - imageSize.width * scale) / 2
            let offY = (size.height - imageSize.height * scale) / 2

            for face in faces {
                let bb = face.boundingBox   // Vision: origem inferior-esquerda
                let rect = CGRect(
                    x: offX + bb.origin.x * imageSize.width * scale,
                    y: offY + (1 - bb.origin.y - bb.height) * imageSize.height * scale,
                    width: bb.width * imageSize.width * scale,
                    height: bb.height * imageSize.height * scale
                )
                let color = color(for: face.decision)
                ctx.stroke(Path(roundedRect: rect, cornerRadius: 8),
                           with: .color(color), lineWidth: face.isPrimary ? 3 : 2)

                let label = labelText(for: face)
                let text = Text(label).font(.caption.weight(.semibold)).foregroundColor(.white)
                let resolved = ctx.resolve(text)
                let textSize = resolved.measure(in: CGSize(width: 320, height: 30))
                let bgRect = CGRect(x: rect.minX, y: max(0, rect.minY - textSize.height - 8),
                                    width: textSize.width + 14, height: textSize.height + 6)
                ctx.fill(Path(roundedRect: bgRect, cornerRadius: 5), with: .color(color.opacity(0.92)))
                ctx.draw(resolved, at: CGPoint(x: bgRect.minX + 7, y: bgRect.midY), anchor: .leading)
            }
        }
    }

    private func color(for decision: AccessDecision) -> Color {
        switch decision {
        case .granted: return Brand.accent
        case .alert: return Brand.accent2
        case .blocked: return Brand.red
        case .checkLiveness: return Brand.amber
        case .denied: return Brand.red
        case .unknown: return Brand.amber
        }
    }

    private func labelText(for face: FaceResult) -> String {
        let pct = Int(face.confidence * 100)
        switch face.decision {
        case .granted(let p): return "\(p.name) · \(pct)%"
        case .alert(let p): return "🔔 \(p.name) · \(pct)%"
        case .blocked(let p): return "⛔️ \(p.name) · bloqueada"
        case .checkLiveness: return "Pisque para confirmar…"
        case .denied: return "Acesso negado"
        case .unknown: return "Desconhecido"
        }
    }
}
