import Foundation

/// Um registro de tentativa de acesso (liberado ou negado), com foto do
/// instante para auditoria.
struct AccessEvent: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var timestamp: Date
    var personID: UUID?
    var personName: String?
    var granted: Bool
    var confidence: Double
    var thumbnailJPEG: Data?

    static func == (lhs: AccessEvent, rhs: AccessEvent) -> Bool { lhs.id == rhs.id }
}
