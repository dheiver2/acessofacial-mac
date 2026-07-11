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

/// Situação da pessoa na lista de vigilância (watchlist).
/// - normal: acesso concedido normalmente.
/// - alerta: acesso concedido, porém dispara notificação (VIP / pessoa a monitorar).
/// - bloqueada: acesso negado e dispara alarme, mesmo com rosto reconhecido.
enum PersonStatus: String, Codable, CaseIterable, Identifiable {
    case normal, alerta, bloqueada
    var id: String { rawValue }
    var label: String {
        switch self {
        case .normal: return "Normal"
        case .alerta: return "Alerta"
        case .bloqueada: return "Bloqueada"
        }
    }
    var systemImage: String {
        switch self {
        case .normal: return "checkmark.circle"
        case .alerta: return "bell.badge"
        case .bloqueada: return "hand.raised.slash"
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
    var status: PersonStatus = .normal

    init(id: UUID = UUID(), name: String, role: String, accessLevel: AccessLevel,
         embeddings: [FaceSample], createdAt: Date = Date(), active: Bool = true,
         status: PersonStatus = .normal) {
        self.id = id; self.name = name; self.role = role; self.accessLevel = accessLevel
        self.embeddings = embeddings; self.createdAt = createdAt; self.active = active
        self.status = status
    }

    // Decodificação tolerante: cadastros antigos (sem `status`) são migrados
    // para `.normal` automaticamente.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        role = try c.decode(String.self, forKey: .role)
        accessLevel = try c.decode(AccessLevel.self, forKey: .accessLevel)
        embeddings = try c.decode([FaceSample].self, forKey: .embeddings)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
        status = try c.decodeIfPresent(PersonStatus.self, forKey: .status) ?? .normal
    }

    static func == (lhs: Person, rhs: Person) -> Bool { lhs.id == rhs.id }
}
