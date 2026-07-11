import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AccessLogView: View {
    @EnvironmentObject var db: FaceDatabase
    @State private var confirmClear = false
    @State private var query = ""
    @State private var filter: AccessKind? = nil
    @State private var exportMessage: String?

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f
    }()

    private var filtered: [AccessEvent] {
        db.events.filter { e in
            (filter == nil || e.kind == filter) &&
            (query.isEmpty || (e.personName ?? "Desconhecido").localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            if let exportMessage {
                Text(exportMessage).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.bottom, 6)
            }
            if filtered.isEmpty {
                ContentUnavailableView {
                    Label(db.events.isEmpty ? "Nenhum registro ainda" : "Nada encontrado",
                          systemImage: "clock.badge.questionmark")
                } description: {
                    Text(db.events.isEmpty
                         ? "As tentativas de acesso liberado, negado ou bloqueado aparecerão aqui."
                         : "Ajuste a busca ou o filtro.")
                }
            } else {
                List(filtered) { event in
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
                        Label(event.kind.label, systemImage: icon(event.kind))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(event.kind))
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Registros de acesso")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { exportCSV() } label: {
                    Label("Exportar CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(db.events.isEmpty)
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

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("Buscar por pessoa", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
            Picker("Filtro", selection: $filter) {
                Text("Todos").tag(AccessKind?.none)
                Text("Liberado").tag(AccessKind?.some(.liberado))
                Text("Negado").tag(AccessKind?.some(.negado))
                Text("Bloqueado").tag(AccessKind?.some(.bloqueado))
                Text("Alerta").tag(AccessKind?.some(.alerta))
                Text("Desconhecido").tag(AccessKind?.some(.desconhecido))
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 180)
            Spacer()
            Text("\(filtered.count) de \(db.events.count)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func icon(_ k: AccessKind) -> String {
        switch k {
        case .liberado: return "checkmark.circle.fill"
        case .alerta: return "bell.badge.fill"
        case .bloqueado: return "hand.raised.slash.fill"
        case .negado: return "xmark.octagon.fill"
        case .desconhecido: return "questionmark.circle.fill"
        }
    }
    private func color(_ k: AccessKind) -> Color {
        switch k {
        case .liberado: return Brand.accent
        case .alerta: return Brand.accent2
        case .bloqueado, .negado: return Brand.red
        case .desconhecido: return Brand.amber
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "registros-acesso.csv"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try db.eventsCSV().write(to: url, atomically: true, encoding: .utf8)
                exportMessage = "✓ Exportado para \(url.lastPathComponent)"
            } catch {
                exportMessage = "✗ Falha ao exportar: \(error.localizedDescription)"
            }
        }
    }
}
