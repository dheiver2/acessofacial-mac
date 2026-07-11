import SwiftUI

struct MonitorView: View {
    @EnvironmentObject var db: FaceDatabase
    @ObservedObject var vm: MonitorViewModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                CameraPreviewView(image: vm.camera.latestImage, faces: vm.faces, match: vm.lastMatch)
                    .overlay(alignment: .top) { bannerView }
            }
            statusBar
        }
        .background(Brand.bg)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner = vm.banner {
            HStack(spacing: 10) {
                Image(systemName: icon(for: banner))
                Text(text(for: banner)).font(.headline)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(color(for: banner), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            .padding(.top, 18)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(duration: 0.3), value: vm.banner)
        }
    }

    private func icon(for b: Banner) -> String {
        switch b {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.octagon.fill"
        case .desconhecido: return "questionmark.circle.fill"
        }
    }
    private func text(for b: Banner) -> String {
        switch b {
        case .granted(let name): return "Acesso liberado — \(name)"
        case .denied: return "Acesso negado"
        case .desconhecido: return "Rosto não cadastrado"
        }
    }
    private func color(for b: Banner) -> Color {
        switch b {
        case .granted: return Brand.accent
        case .denied: return Brand.red
        case .desconhecido: return Brand.amber
        }
    }

    private var statusBar: some View {
        HStack(spacing: 16) {
            Label(vm.camera.running ? "Câmera ativa" : "Câmera parada",
                  systemImage: vm.camera.running ? "video.fill" : "video.slash")
                .foregroundStyle(vm.camera.running ? Brand.accent : Brand.muted)
            Label("\(db.people.count) cadastrados", systemImage: "person.2.fill")
                .foregroundStyle(.secondary)
            if let err = vm.camera.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Brand.red)
            }
            Spacer()
            Text("Limiar: \(Int(db.matchThreshold * 100))%").foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(VisualEffectBackground(material: .headerView))
    }
}
