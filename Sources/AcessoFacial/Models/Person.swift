import Foundation

/// Uma amostra de rosto cadastrada (feature print arquivado + miniatura para
/// exibição na UI).
struct FaceSample: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var data: Data           // VNFeaturePrintObservation arquivado (NSKeyedArchiver)
    var thumbnailJPEG: Data  // miniatura do rosto recortado, para exibir na lista
    var capturedAt: Date
}

/// Nível de acesso concedido a uma pessoa cadastrada.
enum AccessLevel: String, Codable, CaseIterable, Identifiable {
    case admin, staff, visitante
    var id: String { rawValue }
    var label: String {
        switch self {
        case .admin: return "Administrador"
        case .staff: return "Colaborador"
        case .visitante: return "Visitante"
        }
    }
}

/// Uma pessoa cadastrada no sistema de controle de acesso.
struct Person: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var role: String
    var accessLevel: AccessLevel
    var embeddings: [FaceSample]
    var createdAt: Date = Date()
    var active: Bool = true

    static func == (lhs: Person, rhs: Person) -> Bool { lhs.id == rhs.id }
}
