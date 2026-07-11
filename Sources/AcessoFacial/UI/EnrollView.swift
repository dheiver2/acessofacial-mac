import SwiftUI

/// Tela de cadastro: captura 1–5 amostras do rosto ao vivo e salva uma nova
/// pessoa (ou adiciona amostras a uma pessoa existente).
struct EnrollView: View {
    @EnvironmentObject var db: FaceDatabase
    let camera: CameraController

    @State private var name = ""
    @State private var role = ""
    @State private var accessLevel: AccessLevel = .staff
    @State private var samples: [FaceSample] = []
    @State private var isCapturing = false
    @State private var statusMessage: String?
    @State private var noFaceWarning = false

    private let minSamples = 3

    var body: some View {
        HSplitView {
            captureColumn.frame(minWidth: 420, idealWidth: 480)
            formColumn.frame(minWidth: 320, idealWidth: 380)
        }
        .navigationTitle("Cadastrar pessoa")
    }

    private var captureColumn: some View {
        VStack(spacing: 14) {
            CameraPreviewView(image: camera.latestImage, faces: [], match: nil)
                .aspectRatio(4/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Brand.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

            if noFaceWarning {
                Label("Nenhum rosto detectado — centralize o rosto na câmera.", systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(Brand.amber)
            }

            Button {
                capture()
            } label: {
                Label(isCapturing ? "Capturando…" : "Capturar amostra", systemImage: "camera.aperture")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.accent)
            .controlSize(.large)
            .disabled(isCapturing)

            Text("\(samples.count) amostra(s) capturada(s) — recomendado no mínimo \(minSamples), em ângulos levemente diferentes.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !samples.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(samples) { sample in
                            ZStack(alignment: .topTrailing) {
                                if let img = ImageUtils.nsImage(from: sample.thumbnailJPEG) {
                                    Image(nsImage: img).resizable().scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                Button {
                                    samples.removeAll { $0.id == sample.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, Brand.red)
                                }
                                .buttonStyle(.plain)
                                .padding(3)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .background(Brand.bg)
    }

    private var formColumn: some View {
        Form {
            Section("Dados da pessoa") {
                TextField("Nome completo", text: $name)
                TextField("Cargo / função", text: $role)
                Picker("Nível de acesso", selection: $accessLevel) {
                    ForEach(AccessLevel.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
            }
            if let statusMessage {
                Section {
                    Text(statusMessage).foregroundStyle(.secondary).font(.callout)
                }
            }
            Section {
                Button {
                    save()
                } label: {
                    Label("Salvar cadastro", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.accent)
                .disabled(!canSave)
            }
        }
        .formStyle(.grouped)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !samples.isEmpty
    }

    private func capture() {
        guard let image = camera.snapshot() else { return }
        isCapturing = true
        noFaceWarning = false
        Task.detached(priority: .userInitiated) {
            let faces = FaceDetector.detect(in: image)
            guard let face = faces.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
                  let crop = FaceDetector.crop(face, from: image) else {
                await MainActor.run { self.isCapturing = false; self.noFaceWarning = true }
                return
            }
            guard let fp = FaceEmbedding.compute(from: crop),
                  let archived = FaceEmbedding.archive(fp),
                  let thumb = ImageUtils.jpegThumbnail(crop) else {
                await MainActor.run { self.isCapturing = false; self.statusMessage = "Falha ao processar o rosto — tente novamente." }
                return
            }
            let sample = FaceSample(data: archived, thumbnailJPEG: thumb, capturedAt: Date())
            await MainActor.run {
                self.samples.append(sample)
                self.isCapturing = false
                self.statusMessage = nil
            }
        }
    }

    private func save() {
        let person = Person(name: name.trimmingCharacters(in: .whitespaces),
                            role: role.trimmingCharacters(in: .whitespaces),
                            accessLevel: accessLevel,
                            embeddings: samples)
        db.addPerson(person)
        name = ""; role = ""; accessLevel = .staff; samples = []
        statusMessage = "✓ \(person.name) cadastrado(a) com sucesso."
    }
}
