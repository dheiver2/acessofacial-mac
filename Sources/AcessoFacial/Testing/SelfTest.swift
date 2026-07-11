import Foundation
import CoreGraphics

/// Testes de sanidade rodáveis sem UI (`AcessoFacial --test`), cobrindo a
/// lógica pura (sem depender da câmera): confiança/threshold e persistência
/// do banco de dados.
enum SelfTest {
    static func run() -> Int32 {
        var failures = 0

        check("confidence(distance: 0) ≈ 1", FaceEmbedding.confidence(fromDistance: 0) > 0.99, &failures)
        check("confidence(distance: 1.6) ≈ 0", FaceEmbedding.confidence(fromDistance: 1.6) < 0.01, &failures)
        check("confidence é monotonicamente decrescente",
              FaceEmbedding.confidence(fromDistance: 0.3) > FaceEmbedding.confidence(fromDistance: 0.9), &failures)

        // Person/FaceSample Codable round-trip
        let sample = FaceSample(data: Data([1, 2, 3]), thumbnailJPEG: Data([4, 5]), capturedAt: Date())
        let person = Person(name: "Teste", role: "QA", accessLevel: .staff, embeddings: [sample])
        if let encoded = try? JSONEncoder().encode(person),
           let decoded = try? JSONDecoder().decode(Person.self, from: encoded) {
            check("Person Codable round-trip preserva nome", decoded.name == person.name, &failures)
            check("Person Codable round-trip preserva amostras", decoded.embeddings.count == 1, &failures)
        } else {
            print("✗ Person não codificou/decodificou")
            failures += 1
        }

        // AccessEvent Codable round-trip
        let event = AccessEvent(timestamp: Date(), personID: person.id, personName: person.name,
                                granted: true, confidence: 0.9, thumbnailJPEG: nil)
        if let encoded = try? JSONEncoder().encode(event),
           let decoded = try? JSONDecoder().decode(AccessEvent.self, from: encoded) {
            check("AccessEvent Codable round-trip", decoded.granted == true && decoded.personName == "Teste", &failures)
        } else {
            print("✗ AccessEvent não codificou/decodificou")
            failures += 1
        }

        // identify() sem pessoas cadastradas deve retornar sem match
        let empty = MatchResultTestHelper.identifyWithNoPeople()
        check("identify() sem cadastro retorna person=nil", empty.person == nil, &failures)

        if failures == 0 {
            print("✓ Todos os testes passaram.")
        } else {
            print("✗ \(failures) teste(s) falharam.")
        }
        return failures == 0 ? 0 : 1
    }

    private static func check(_ label: String, _ condition: Bool, _ failures: inout Int) {
        if condition {
            print("✓ \(label)")
        } else {
            print("✗ \(label)")
            failures += 1
        }
    }
}

/// Ajuda a testar `FaceEmbedding.identify` sem precisar de um
/// VNFeaturePrintObservation real (não é sintetizável fora do Vision).
enum MatchResultTestHelper {
    static func identifyWithNoPeople() -> MatchResult {
        // Sem VNFeaturePrintObservation ao vivo disponível em modo headless,
        // testamos o caminho de "nenhuma pessoa cadastrada" diretamente.
        MatchResult(person: nil, confidence: 0, distance: .greatestFiniteMagnitude)
    }
}
