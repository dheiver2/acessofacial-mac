import Foundation
import CoreGraphics
import Combine

enum Banner: Equatable {
    case granted(name: String)
    case denied
    case desconhecido
}

/// Orquestra câmera + detecção + reconhecimento facial, com throttling
/// (não roda o pipeline pesado a cada frame) e cooldown de log para não
/// duplicar registros de acesso da mesma pessoa em sequência.
@MainActor
final class MonitorViewModel: ObservableObject {
    let camera: CameraController
    @Published private(set) var faces: [DetectedFace] = []
    @Published private(set) var lastMatch: MatchResult?
    @Published private(set) var banner: Banner?
    @Published private(set) var isProcessing = false

    private let db: FaceDatabase
    private var ticker: AnyCancellable?
    private var bannerDismiss: DispatchWorkItem?
    private var lastEventKey: String?
    private var lastEventAt = Date.distantPast
    private let cooldown: TimeInterval = 6

    /// `camera` já deve estar rodando (dono do ciclo de vida é a RootView,
    /// compartilhada com a tela de Cadastro). Este view model só liga/desliga
    /// o laço de reconhecimento facial.
    init(camera: CameraController, db: FaceDatabase) {
        self.camera = camera
        self.db = db
    }

    func start() {
        ticker = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stop() {
        ticker?.cancel()
        faces = []
        lastMatch = nil
    }

    private func tick() {
        guard let image = camera.snapshot(), !isProcessing else { return }
        isProcessing = true
        let threshold = db.matchThreshold
        let people = db.people

        Task.detached(priority: .userInitiated) {
            let detected = FaceDetector.detect(in: image)
            let primary = detected.max(by: { $0.boundingBox.width < $1.boundingBox.width })
            var match: MatchResult?
            var thumb: Data?

            if let primary {
                if let crop = FaceDetector.crop(primary, from: image) {
                    thumb = ImageUtils.jpegThumbnail(crop)
                    if let fp = FaceEmbedding.compute(from: crop) {
                        match = FaceEmbedding.identify(fp, against: people, threshold: threshold)
                    }
                }
            }

            await MainActor.run { [match, thumb, primary] in
                self.isProcessing = false
                self.faces = detected
                self.apply(match: match, hasFace: primary != nil, thumbnail: thumb)
            }
        }
    }

    private func apply(match: MatchResult?, hasFace: Bool, thumbnail: Data?) {
        lastMatch = match
        guard hasFace else { return }

        let now = Date()
        if let person = match?.person {
            showBanner(.granted(name: person.name))
            let key = "granted:\(person.id)"
            if key != lastEventKey || now.timeIntervalSince(lastEventAt) > cooldown {
                lastEventKey = key
                lastEventAt = now
                db.logEvent(AccessEvent(timestamp: now, personID: person.id, personName: person.name,
                                         granted: true, confidence: match?.confidence ?? 0,
                                         thumbnailJPEG: thumbnail))
            }
        } else if let match {
            let known = match.distance < 1.0
            showBanner(known ? .denied : .desconhecido)
            let key = known ? "denied" : "unknown"
            if key != lastEventKey || now.timeIntervalSince(lastEventAt) > cooldown {
                lastEventKey = key
                lastEventAt = now
                db.logEvent(AccessEvent(timestamp: now, personID: nil, personName: nil,
                                         granted: false, confidence: match.confidence,
                                         thumbnailJPEG: thumbnail))
            }
        }
    }

    private func showBanner(_ b: Banner) {
        banner = b
        bannerDismiss?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.banner = nil }
        bannerDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
}
