import Foundation

/// Tipo de decisão registrada, para exibição e exportação.
enum AccessKind: String, Codable {
    case liberado, negado, desconhecido, bloqueado, alerta

    var label: String {
        switch self {
        case .liberado: return "Liberado"
        case .negado: return "Negado"
        case .desconhecido: return "Desconhecido"
        case .bloqueado: return "Bloqueado"
        case .alerta: return "Alerta"
        }
    }
    var granted: Bool { self == .liberado || self == .alerta }
}

/// Um registro de tentativa de acesso, com foto do instante para auditoria.
struct AccessEvent: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var timestamp: Date
    var personID: UUID?
    var personName: String?
    var kind: AccessKind
    var confidence: Double
    var thumbnailJPEG: Data?

    init(id: UUID = UUID(), timestamp: Date, personID: UUID?, personName: String?,
         kind: AccessKind, confidence: Double, thumbnailJPEG: Data?) {
        self.id = id; self.timestamp = timestamp; self.personID = personID
        self.personName = personName; self.kind = kind; self.confidence = confidence
        self.thumbnailJPEG = thumbnailJPEG
    }

    // Decodificação tolerante para registros gravados antes do campo `kind`
    // (que usavam `granted: Bool`).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        personID = try c.decodeIfPresent(UUID.self, forKey: .personID)
        personName = try c.decodeIfPresent(String.self, forKey: .personName)
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        thumbnailJPEG = try c.decodeIfPresent(Data.self, forKey: .thumbnailJPEG)
        if let k = try c.decodeIfPresent(AccessKind.self, forKey: .kind) {
            kind = k
        } else {
            let granted = (try? c.decode(Bool.self, forKey: .granted)) ?? false
            kind = granted ? .liberado : .negado
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(personID, forKey: .personID)
        try c.encodeIfPresent(personName, forKey: .personName)
        try c.encode(kind, forKey: .kind)
        try c.encode(confidence, forKey: .confidence)
        try c.encodeIfPresent(thumbnailJPEG, forKey: .thumbnailJPEG)
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, personID, personName, kind, confidence, thumbnailJPEG, granted
    }

    static func == (lhs: AccessEvent, rhs: AccessEvent) -> Bool { lhs.id == rhs.id }
}
