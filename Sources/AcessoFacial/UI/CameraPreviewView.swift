import SwiftUI
import CoreGraphics

/// Exibe o quadro atual da câmera com overlay das caixas de rosto detectadas
/// e um rótulo de identificação (nome + confiança, ou "desconhecido").
struct CameraPreviewView: View {
    let image: CGImage?
    let faces: [DetectedFace]
    let match: MatchResult?

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
                // Vision: bounding box normalizado, origem inferior-esquerda.
                let bb = face.boundingBox
                let rect = CGRect(
                    x: offX + bb.origin.x * imageSize.width * scale,
                    y: offY + (1 - bb.origin.y - bb.height) * imageSize.height * scale,
                    width: bb.width * imageSize.width * scale,
                    height: bb.height * imageSize.height * scale
                )
                let color = boxColor(for: face)
                let path = Path(roundedRect: rect, cornerRadius: 8)
                ctx.stroke(path, with: .color(color), lineWidth: 2.5)

                if isPrimary(face) {
                    let label = labelText()
                    let text = Text(label).font(.caption.weight(.semibold)).foregroundColor(.white)
                    let resolved = ctx.resolve(text)
                    let textSize = resolved.measure(in: CGSize(width: 300, height: 30))
                    let bgRect = CGRect(x: rect.minX, y: max(0, rect.minY - textSize.height - 8),
                                        width: textSize.width + 14, height: textSize.height + 6)
                    ctx.fill(Path(roundedRect: bgRect, cornerRadius: 5), with: .color(color.opacity(0.9)))
                    ctx.draw(resolved, at: CGPoint(x: bgRect.minX + 7, y: bgRect.midY), anchor: .leading)
                }
            }
        }
    }

    private func isPrimary(_ face: DetectedFace) -> Bool {
        guard let biggest = faces.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { return false }
        return face.boundingBox == biggest.boundingBox
    }

    private func boxColor(for face: DetectedFace) -> Color {
        guard isPrimary(face) else { return Brand.accent2.opacity(0.7) }
        if let match, match.person != nil { return Brand.accent }
        if let match, match.distance < 1.0 { return Brand.red }
        return Brand.amber
    }

    private func labelText() -> String {
        if let match, let person = match.person {
            return "\(person.name) · \(Int(match.confidence * 100))%"
        } else if let match {
            return match.distance < 1.0 ? "Acesso negado" : "Desconhecido"
        }
        return "Analisando…"
    }
}
