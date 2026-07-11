import SwiftUI

/// Identidade visual nativa macOS: cores semânticas adaptativas (claro/escuro)
/// com um acento verde-esmeralda (segurança/acesso) como tint principal.
enum Brand {
    static let accent    = Color(hex: 0x1FA97B)   // verde esmeralda — liberado
    static let accent2   = Color(hex: 0x2E8FE0)   // azul — informativo
    static let amber     = Color(hex: 0xD9A521)   // atenção / desconhecido
    static let red       = Color(hex: 0xE0524D)   // negado / erro

    static let text      = Color.primary
    static let muted     = Color.secondary
    static let faint     = Color.secondary.opacity(0.65)
    static let bg        = Color(nsColor: .windowBackgroundColor)
    static let bgElev    = Color(nsColor: .underPageBackgroundColor)
    static let card      = Color(nsColor: .controlBackgroundColor)
    static let border    = Color(nsColor: .separatorColor)

    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x2BC48A), Color(hex: 0x1FA97B), Color(hex: 0x1B7FE0)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static func confidenceColor(_ score: Double) -> Color {
        switch score {
        case 0.82...: return accent
        case 0.6..<0.82: return amber
        default: return red
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension View {
    func sectionLabel() -> some View {
        self.font(.caption2.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}

/// Marca em miniatura (escudo com check) usada na toolbar/sidebar.
struct BrandMark: View {
    var size: CGFloat = 20
    var body: some View {
        ZStack {
            SwiftUI.Circle().fill(Brand.brandGradient)
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
