import Foundation
import CoreGraphics

/// Testes de sanidade rodáveis sem UI (`AcessoFacial --test`), cobrindo a
/// lógica pura (sem depender da câmera): confiança/threshold, persistência,
/// liveness e migração de dados antigos.
enum SelfTest {
    static func run() -> Int32 {
        var failures = 0

        // ── Confiança / limiar
        check("confidence(distance: 0) ≈ 1", FaceEmbedding.confidence(fromDistance: 0) > 0.99, &failures)
        check("confidence(distance: 1.6) ≈ 0", FaceEmbedding.confidence(fromDistance: 1.6) < 0.01, &failures)
        check("confidence é monotonicamente decrescente",
              FaceEmbedding.confidence(fromDistance: 0.3) > FaceEmbedding.confidence(fromDistance: 0.9), &failures)

        // ── Person Codable + status
        let sample = FaceSample(data: Data([1, 2, 3]), thumbnailJPEG: Data([4, 5]), capturedAt: Date())
        let person = Person(name: "Teste", role: "QA", accessLevel: .staff, embeddings: [sample], status: .bloqueada)
        if let encoded = try? JSONEncoder().encode(person),
           let decoded = try? JSONDecoder().decode(Person.self, from: encoded) {
            check("Person Codable preserva nome", decoded.name == person.name, &failures)
            check("Person Codable preserva status", decoded.status == .bloqueada, &failures)
        } else {
            print("✗ Person não codificou/decodificou"); failures += 1
        }

        // ── Migração: Person antigo SEM campo `status` vira .normal
        let legacyPerson = """
        {"id":"\(UUID().uuidString)","name":"Antigo","role":"","accessLevel":"staff","embeddings":[],"createdAt":0,"active":true}
        """.data(using: .utf8)!
        if let p = try? JSONDecoder().decode(Person.self, from: legacyPerson) {
            check("Person legado (sem status) migra p/ .normal", p.status == .normal, &failures)
        } else {
            print("✗ Person legado não decodificou"); failures += 1
        }

        // ── AccessEvent Codable + migração de `granted` p/ `kind`
        let event = AccessEvent(timestamp: Date(), personID: person.id, personName: person.name,
                                kind: .bloqueado, confidence: 0.9, thumbnailJPEG: nil)
        if let encoded = try? JSONEncoder().encode(event),
           let decoded = try? JSONDecoder().decode(AccessEvent.self, from: encoded) {
            check("AccessEvent Codable preserva kind", decoded.kind == .bloqueado, &failures)
        } else {
            print("✗ AccessEvent não codificou/decodificou"); failures += 1
        }
        let legacyEvent = """
        {"id":"\(UUID().uuidString)","timestamp":0,"granted":true,"confidence":0.8}
        """.data(using: .utf8)!
        if let e = try? JSONDecoder().decode(AccessEvent.self, from: legacyEvent) {
            check("AccessEvent legado (granted:true) migra p/ .liberado", e.kind == .liberado, &failures)
        } else {
            print("✗ AccessEvent legado não decodificou"); failures += 1
        }

        // ── Liveness: constante = não vivo; variação = vivo
        let flat = LivenessTracker()
        for _ in 0..<8 { flat.feed(0.05) }
        check("Liveness rejeita abertura ocular constante (foto)", flat.isLive == false, &failures)
        let blink = LivenessTracker()
        for v in [0.06, 0.06, 0.05, 0.01, 0.02, 0.06, 0.06, 0.05] { blink.feed(v) }
        check("Liveness aceita variação (piscada)", blink.isLive == true, &failures)

        // ── CSV
        check("AccessKind.granted mapeia liberado/alerta",
              AccessKind.liberado.granted && AccessKind.alerta.granted && !AccessKind.bloqueado.granted, &failures)

        if failures == 0 {
            print("✓ Todos os testes passaram.")
        } else {
            print("✗ \(failures) teste(s) falharam.")
        }
        return failures == 0 ? 0 : 1
    }

    private static func check(_ label: String, _ condition: Bool, _ failures: inout Int) {
        if condition { print("✓ \(label)") }
        else { print("✗ \(label)"); failures += 1 }
    }
}
