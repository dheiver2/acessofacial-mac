import Foundation
import CoreGraphics
import Combine

enum Banner: Equatable {
    case granted(name: String)
    case alert(name: String)
    case blocked(name: String)
    case denied
    case desconhecido
    case checkLiveness
}

/// Orquestra câmera + detecção + reconhecimento facial de MÚLTIPLOS rostos por
/// quadro, com prova de vida (liveness) e alertas de watchlist. O rosto
/// principal (maior/mais próximo) dirige a decisão de acesso da catraca e o
/// log; qualquer rosto reconhecido em watchlist (bloqueada/alerta) dispara
/// notificação — como fazem sistemas de vigilância especializados.
@MainActor
final class MonitorViewModel: ObservableObject {
    let camera: CameraController
    @Published private(set) var faces: [FaceResult] = []
    @Published private(set) var banner: Banner?
    @Published private(set) var isProcessing = false

    private let db: FaceDatabase
    private let liveness = LivenessTracker()
    private var ticker: AnyCancellable?
    private var bannerDismiss: DispatchWorkItem?
    private var lastEventKey: String?
    private var lastEventAt = Date.distantPast
    private var alertCooldown: [String: Date] = [:]
    private let cooldown: TimeInterval = 6

    init(camera: CameraController, db: FaceDatabase) {
        self.camera = camera
        self.db = db
    }

    func start() {
        Alerter.requestAuthorizationIfNeeded()
        ticker = Timer.publish(every: 0.4, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stop() {
        ticker?.cancel()
        faces = []
        liveness.reset()
    }

    private func tick() {
        guard let image = camera.snapshot(), !isProcessing else { return }
        isProcessing = true
        let threshold = db.matchThreshold
        let people = db.people

        Task.detached(priority: .userInitiated) {
            let detected = FaceDetector.detect(in: image)
            // rosto principal = maior bounding box
            let primaryBox = detected.max(by: { $0.boundingBox.width < $1.boundingBox.width })?.boundingBox

            var results: [(box: CGRect, match: MatchResult, isPrimary: Bool, thumb: Data?, openness: Double?)] = []
            for face in detected {
                let isPrimary = face.boundingBox == primaryBox
                var match = MatchResult(person: nil, confidence: 0, distance: .greatestFiniteMagnitude)
                var thumb: Data?
                if let crop = FaceDetector.crop(face, from: image) {
                    if isPrimary { thumb = ImageUtils.jpegThumbnail(crop) }
                    if let fp = FaceEmbedding.compute(from: crop) {
                        match = FaceEmbedding.identify(fp, against: people, threshold: threshold)
                    }
                }
                let openness = isPrimary ? FaceDetector.eyesOpenRatio(face) : nil
                results.append((face.boundingBox, match, isPrimary, thumb, openness))
            }

            let finalResults = results
            await MainActor.run {
                self.isProcessing = false
                self.consume(finalResults)
            }
        }
    }

    private func consume(_ raw: [(box: CGRect, match: MatchResult, isPrimary: Bool, thumb: Data?, openness: Double?)]) {
        // alimenta liveness com a abertura ocular do rosto principal
        if let primary = raw.first(where: { $0.isPrimary }) {
            liveness.feed(primary.openness)
        } else {
            liveness.reset()
        }
        let live = liveness.isLive
        let requireLiveness = db.requireLiveness

        var out: [FaceResult] = []
        var primaryDecision: (AccessDecision, Data?)?

        for r in raw {
            let decision = decide(match: r.match, isPrimary: r.isPrimary,
                                  live: live, requireLiveness: requireLiveness)
            out.append(FaceResult(boundingBox: r.box, decision: decision,
                                  confidence: r.match.confidence, isPrimary: r.isPrimary))
            // alertas de watchlist disparam para QUALQUER rosto reconhecido
            fireWatchlistAlertIfNeeded(decision)
            if r.isPrimary { primaryDecision = (decision, r.thumb) }
        }
        faces = out

        if let (decision, thumb) = primaryDecision {
            updateBanner(decision)
            logIfNeeded(decision, thumbnail: thumb)
        } else {
            banner = nil
        }
    }

    private func decide(match: MatchResult, isPrimary: Bool, live: Bool, requireLiveness: Bool) -> AccessDecision {
        if let person = match.person {
            switch person.status {
            case .bloqueada: return .blocked(person)
            case .alerta: return .alert(person)
            case .normal:
                if isPrimary && requireLiveness && !live { return .checkLiveness(person) }
                return .granted(person)
            }
        }
        // sem correspondência acima do limiar
        return match.distance < 1.0 ? .denied : .unknown
    }

    // MARK: Alertas de watchlist

    private func fireWatchlistAlertIfNeeded(_ decision: AccessDecision) {
        let now = Date()
        func throttled(_ key: String) -> Bool {
            if let last = alertCooldown[key], now.timeIntervalSince(last) < cooldown { return true }
            alertCooldown[key] = now
            return false
        }
        switch decision {
        case .blocked(let p):
            guard !throttled("blocked:\(p.id)") else { return }
            Alerter.fire(title: "⛔️ Pessoa bloqueada detectada",
                         body: "\(p.name) — acesso negado.", blocked: true, playSound: db.soundEnabled)
        case .alert(let p):
            guard !throttled("alert:\(p.id)") else { return }
            Alerter.fire(title: "🔔 Pessoa em alerta detectada",
                         body: "\(p.name) foi identificada.", blocked: false, playSound: db.soundEnabled)
        default:
            break
        }
    }

    // MARK: Banner + log

    private func updateBanner(_ decision: AccessDecision) {
        switch decision {
        case .granted(let p): showBanner(.granted(name: p.name))
        case .alert(let p): showBanner(.alert(name: p.name))
        case .blocked(let p): showBanner(.blocked(name: p.name))
        case .checkLiveness: showBanner(.checkLiveness)
        case .denied: showBanner(.denied)
        case .unknown: showBanner(.desconhecido)
        }
    }

    private func logIfNeeded(_ decision: AccessDecision, thumbnail: Data?) {
        let now = Date()
        let (kind, person): (AccessKind, Person?)
        switch decision {
        case .granted(let p): (kind, person) = (.liberado, p)
        case .alert(let p): (kind, person) = (.alerta, p)
        case .blocked(let p): (kind, person) = (.bloqueado, p)
        case .denied: (kind, person) = (.negado, nil)
        case .unknown: (kind, person) = (.desconhecido, nil)
        case .checkLiveness: return   // ainda aguardando prova de vida — não registra
        }
        let key = "\(kind.rawValue):\(person?.id.uuidString ?? "-")"
        guard key != lastEventKey || now.timeIntervalSince(lastEventAt) > cooldown else { return }
        lastEventKey = key
        lastEventAt = now
        let conf = faces.first(where: { $0.isPrimary })?.confidence ?? 0
        db.logEvent(AccessEvent(timestamp: now, personID: person?.id, personName: person?.name,
                                kind: kind, confidence: conf, thumbnailJPEG: thumbnail))
    }

    private func showBanner(_ b: Banner) {
        banner = b
        bannerDismiss?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.banner = nil }
        bannerDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }
}
