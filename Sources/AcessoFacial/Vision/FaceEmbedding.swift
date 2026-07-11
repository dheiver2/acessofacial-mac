import Vision
import CoreGraphics
import Foundation

/// Gera e compara "assinaturas" de rosto usando o Vision Feature Print
/// (VNGenerateImageFeaturePrintRequest) — um embedding genérico de imagem,
/// nativo do macOS, sem precisar de nenhum modelo CoreML externo. Aplicado
/// sobre o rosto já recortado pelo FaceDetector, funciona bem para
/// diferenciar indivíduos em um cadastro de porte pequeno/médio.
///
/// VNFeaturePrintObservation adota NSSecureCoding, então persistimos a
/// assinatura via NSKeyedArchiver e a reconstruímos entre sessões do app
/// para comparar com `computeDistance(_:to:)`.
enum FaceEmbedding {
    static func compute(from faceImage: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cgImage: faceImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    static func archive(_ fp: VNFeaturePrintObservation) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: fp, requiringSecureCoding: true)
    }

    static func unarchive(_ data: Data) -> VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }

    /// Distância entre dois feature prints (menor = mais parecido).
    /// Tipicamente 0 (idêntico) a ~2+ (bem diferente).
    static func distance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float? {
        var d: Float = 0
        do {
            try a.computeDistance(&d, to: b)
            return d
        } catch {
            return nil
        }
    }

    /// Confiança normalizada (0...1) a partir da distância bruta do Vision.
    /// Calibrado empiricamente: distâncias abaixo de ~0.6 tendem a ser a
    /// mesma pessoa; acima de ~1.2, pessoas diferentes.
    static func confidence(fromDistance d: Float) -> Double {
        let clamped = max(0, min(d, 1.6))
        return Double(1 - clamped / 1.6)
    }
}

/// Resultado de uma tentativa de identificação contra o banco cadastrado.
struct MatchResult {
    let person: Person?
    let confidence: Double   // 0...1, 1 = idêntico
    let distance: Float
}

extension FaceEmbedding {
    /// Compara um feature print ao vivo contra todas as pessoas cadastradas
    /// e retorna a melhor correspondência (menor distância entre as
    /// amostras cadastradas de cada pessoa).
    static func identify(_ live: VNFeaturePrintObservation,
                          against people: [Person],
                          threshold: Double) -> MatchResult {
        var best: (Person, Float)?
        for person in people {
            for sample in person.embeddings {
                guard let stored = unarchive(sample.data),
                      let d = distance(live, stored) else { continue }
                if best == nil || d < best!.1 { best = (person, d) }
            }
        }
        guard let (person, dist) = best else {
            return MatchResult(person: nil, confidence: 0, distance: .greatestFiniteMagnitude)
        }
        let conf = confidence(fromDistance: dist)
        if conf >= threshold {
            return MatchResult(person: person, confidence: conf, distance: dist)
        }
        return MatchResult(person: nil, confidence: conf, distance: dist)
    }
}
