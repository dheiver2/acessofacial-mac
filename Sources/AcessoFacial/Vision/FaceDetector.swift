import Vision
import CoreGraphics
import CoreImage

/// Um rosto detectado num quadro, em coordenadas normalizadas (origem
/// inferior-esquerda, como o Vision retorna) e com a landmark de olhos
/// (usada para checagem básica de "vivacidade" via abertura ocular).
struct DetectedFace {
    let boundingBox: CGRect       // normalizado 0...1, origem bottom-left
    let landmarks: VNFaceLandmarks2D?
    let roll: NSNumber?
    let yaw: NSNumber?
}

/// Detecção de rosto + landmarks via Vision (nativo, sem modelos externos).
enum FaceDetector {
    static func detect(in image: CGImage) -> [DetectedFace] {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        guard let results = request.results else { return [] }
        return results.map {
            DetectedFace(boundingBox: $0.boundingBox,
                         landmarks: $0.landmarks,
                         roll: $0.roll,
                         yaw: $0.yaw)
        }
    }

    /// Recorta a região do rosto (com uma margem) do quadro original,
    /// em coordenadas de imagem (origem top-left).
    static func crop(_ face: DetectedFace, from image: CGImage, margin: CGFloat = 0.18) -> CGImage? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let bb = face.boundingBox
        let mx = bb.width * margin, my = bb.height * margin
        let expanded = bb.insetBy(dx: -mx, dy: -my)

        // Vision usa origem inferior-esquerda; CGImage cropping usa top-left.
        let rect = CGRect(
            x: expanded.origin.x * w,
            y: (1 - expanded.origin.y - expanded.height) * h,
            width: expanded.width * w,
            height: expanded.height * h
        ).intersection(CGRect(x: 0, y: 0, width: w, height: h))

        guard rect.width > 1, rect.height > 1 else { return nil }
        return image.cropping(to: rect)
    }

    /// Heurística simples de "olhos abertos" a partir dos landmarks, usada
    /// como sinal auxiliar anti-foto-estática (não é liveness robusto).
    static func eyesOpenRatio(_ face: DetectedFace) -> Double? {
        guard let lm = face.landmarks else { return nil }
        func openness(_ region: VNFaceLandmarkRegion2D?) -> Double? {
            guard let region, region.pointCount >= 6 else { return nil }
            let pts = region.normalizedPoints
            let top = pts[1...2].map { $0.y }.reduce(0, +) / 2
            let bottom = pts[4...5].map { $0.y }.reduce(0, +) / 2
            let left = pts[0].x, right = pts[3].x
            let width = abs(right - left)
            guard width > 0 else { return nil }
            return Double(abs(top - bottom) / width)
        }
        let l = openness(lm.leftEye)
        let r = openness(lm.rightEye)
        switch (l, r) {
        case let (a?, b?): return (a + b) / 2
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }
}
