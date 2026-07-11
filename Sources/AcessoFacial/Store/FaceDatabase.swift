import Foundation
import Combine

/// Persistência local (JSON em Application Support) do cadastro de pessoas,
/// do log de acessos e das configurações — sem dependências externas.
@MainActor
final class FaceDatabase: ObservableObject {
    @Published private(set) var people: [Person] = []
    @Published private(set) var events: [AccessEvent] = []
    @Published var matchThreshold: Double = 0.72 { didSet { saveSettings() } }
    /// Exige prova de vida (piscada) antes de liberar acesso.
    @Published var requireLiveness: Bool = true { didSet { saveSettings() } }
    /// Toca som em alertas de watchlist.
    @Published var soundEnabled: Bool = true { didSet { saveSettings() } }

    private let dir: URL
    private let peopleURL: URL
    private let eventsURL: URL
    private let settingsURL: URL
    private let maxEvents = 500

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("AcessoFacial", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        peopleURL = dir.appendingPathComponent("pessoas.json")
        eventsURL = dir.appendingPathComponent("registros.json")
        settingsURL = dir.appendingPathComponent("config.json")
        load()
    }

    // MARK: Pessoas

    func addPerson(_ person: Person) {
        people.append(person)
        savePeople()
    }

    func updatePerson(_ person: Person) {
        guard let idx = people.firstIndex(where: { $0.id == person.id }) else { return }
        people[idx] = person
        savePeople()
    }

    func deletePerson(_ id: UUID) {
        people.removeAll { $0.id == id }
        savePeople()
    }

    func addSample(_ sample: FaceSample, to personID: UUID) {
        guard let idx = people.firstIndex(where: { $0.id == personID }) else { return }
        people[idx].embeddings.append(sample)
        savePeople()
    }

    // MARK: Log de acesso

    func logEvent(_ event: AccessEvent) {
        events.insert(event, at: 0)
        if events.count > maxEvents { events.removeLast(events.count - maxEvents) }
        saveEvents()
    }

    func clearEvents() {
        events.removeAll()
        saveEvents()
    }

    // MARK: Persistência

    private func load() {
        if let data = try? Data(contentsOf: peopleURL),
           let decoded = try? JSONDecoder().decode([Person].self, from: data) {
            people = decoded
        }
        if let data = try? Data(contentsOf: eventsURL),
           let decoded = try? JSONDecoder().decode([AccessEvent].self, from: data) {
            events = decoded
        }
        if let data = try? Data(contentsOf: settingsURL),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            matchThreshold = decoded.matchThreshold
            requireLiveness = decoded.requireLiveness ?? true
            soundEnabled = decoded.soundEnabled ?? true
        }
    }

    private struct Settings: Codable {
        var matchThreshold: Double
        var requireLiveness: Bool?
        var soundEnabled: Bool?
    }

    private func savePeople() {
        guard let data = try? JSONEncoder().encode(people) else { return }
        try? data.write(to: peopleURL, options: .atomic)
    }

    private func saveEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: eventsURL, options: .atomic)
    }

    private func saveSettings() {
        let s = Settings(matchThreshold: matchThreshold,
                         requireLiveness: requireLiveness,
                         soundEnabled: soundEnabled)
        guard let data = try? JSONEncoder().encode(s) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    // MARK: Exportação

    /// Gera o conteúdo CSV do log de acesso (para auditoria).
    func eventsCSV() -> String {
        let df = ISO8601DateFormatter()
        var rows = ["data_hora,pessoa,resultado,confianca_pct"]
        for e in events {
            let name = (e.personName ?? "Desconhecido").replacingOccurrences(of: "\"", with: "'")
            rows.append("\(df.string(from: e.timestamp)),\"\(name)\",\(e.kind.label),\(Int(e.confidence * 100))")
        }
        return rows.joined(separator: "\n")
    }
}
