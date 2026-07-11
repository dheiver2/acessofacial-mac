import Foundation

/// Detector de prova de vida (anti-spoofing) simples e nativo, baseado na
/// variação da abertura ocular do rosto principal ao longo de uma janela curta.
///
/// Uma foto/vídeo estático apresenta abertura ocular praticamente constante;
/// um rosto vivo pisca e se move, gerando variação relativa detectável. Não é
/// um liveness robusto de grau bancário (que exigiria sensor de profundidade
/// ou desafio ativo), mas cobre o ataque mais comum: apresentar uma foto
/// impressa ou na tela do celular ao leitor.
final class LivenessTracker {
    private var samples: [(t: Date, open: Double)] = []
    private let window: TimeInterval = 2.2
    private let minSamples = 5
    /// Variação relativa mínima da abertura ocular para considerar "vivo".
    private let relativeThreshold = 0.30

    func feed(_ openness: Double?) {
        let now = Date()
        if let openness { samples.append((now, openness)) }
        samples.removeAll { now.timeIntervalSince($0.t) > window }
    }

    func reset() { samples.removeAll() }

    /// `true` quando houve variação suficiente na abertura ocular na janela.
    var isLive: Bool {
        guard samples.count >= minSamples else { return false }
        let vals = samples.map { $0.open }
        guard let mn = vals.min(), let mx = vals.max(), mx > 1e-4 else { return false }
        return (mx - mn) / mx >= relativeThreshold
    }
}
