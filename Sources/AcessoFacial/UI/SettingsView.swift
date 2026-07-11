import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var db: FaceDatabase
    let camera: CameraController

    var body: some View {
        Form {
            Section("Reconhecimento") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Limiar de confiança")
                        Spacer()
                        Text("\(Int(db.matchThreshold * 100))%").foregroundStyle(.secondary)
                    }
                    Slider(value: $db.matchThreshold, in: 0.5...0.95, step: 0.01)
                    Text("Quanto maior, mais rigoroso o reconhecimento (menos falsos positivos, porém mais rejeições).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Câmera") {
                if camera.availableDevices.isEmpty {
                    Text("Nenhuma câmera detectada.").foregroundStyle(.secondary)
                } else {
                    Picker("Dispositivo", selection: Binding(
                        get: { camera.selectedDeviceID ?? "" },
                        set: { camera.switchCamera(to: $0) }
                    )) {
                        ForEach(camera.availableDevices, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }
                }
                Button("Atualizar lista de câmeras") { camera.refreshDevices() }
            }

            Section("Dados") {
                LabeledContent("Pessoas cadastradas", value: "\(db.people.count)")
                LabeledContent("Registros de acesso", value: "\(db.events.count)")
            }

            Section("Sobre") {
                Text("Acesso Facial — reconhecimento facial 100% nativo e local, usando AVFoundation + Vision. Nenhuma imagem ou dado biométrico sai do seu Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Configurações")
    }
}
