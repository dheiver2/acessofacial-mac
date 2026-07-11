import Foundation
import CoreGraphics

/// Decisão de acesso calculada para um rosto detectado no quadro.
enum AccessDecision: Equatable {
    case granted(Person)         // reconhecido, acesso liberado
    case alert(Person)           // reconhecido, mas em watchlist de alerta (libera + notifica)
    case blocked(Person)         // reconhecido, porém bloqueado (nega + alarme)
    case checkLiveness(Person)   // reconhecido, aguardando prova de vida (piscada)
    case denied                  // parecido com alguém, mas abaixo do limiar
    case unknown                 // nenhuma correspondência

    var person: Person? {
        switch self {
        case .granted(let p), .alert(let p), .blocked(let p), .checkLiveness(let p): return p
        default: return nil
        }
    }
}

/// Resultado do pipeline para um único rosto: onde está e o que decidimos.
struct FaceResult: Identifiable {
    let id = UUID()
    let boundingBox: CGRect      // normalizado (Vision, origem inferior-esquerda)
    let decision: AccessDecision
    let confidence: Double
    var isPrimary: Bool          // rosto mais próximo/maior — dirige a catraca
}
