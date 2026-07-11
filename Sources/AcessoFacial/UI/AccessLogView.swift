import SwiftUI

struct AccessLogView: View {
    @EnvironmentObject var db: FaceDatabase
    @State private var confirmClear = false

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            if db.events.isEmpty {
                ContentUnavailableView {
                    Label("Nenhum registro ainda", systemImage: "clock.badge.questionmark")
                } description: {
                    Text("As tentativas de acesso liberado ou negado aparecerão aqui.")
                }
            } else {
                List(db.events) { event in
                    HStack(spacing: 12) {
                        if let img = ImageUtils.nsImage(from: event.thumbnailJPEG) {
                            Image(nsImage: img).resizable().scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(Brand.card)
                                .frame(width: 40, height: 40)
                                .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.personName ?? "Desconhecido").font(.headline)
                            Text(Self.formatter.string(from: event.timestamp))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(event.confidence * 100))%").font(.caption).foregroundStyle(.secondary)
                        Label(event.granted ? "Liberado" : "Negado",
                              systemImage: event.granted ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(event.granted ? Brand.accent : Brand.red)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Registros de acesso")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) { confirmClear = true } label: {
                    Label("Limpar", systemImage: "trash")
                }
                .disabled(db.events.isEmpty)
            }
        }
        .alert("Limpar todos os registros?", isPresented: $confirmClear) {
            Button("Cancelar", role: .cancel) {}
            Button("Limpar", role: .destructive) { db.clearEvents() }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
    }
}
