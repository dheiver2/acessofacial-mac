import SwiftUI

struct PeopleListView: View {
    @EnvironmentObject var db: FaceDatabase
    @State private var query = ""
    @State private var personPendingDelete: Person?

    private var filtered: [Person] {
        guard !query.isEmpty else { return db.people }
        return db.people.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.role.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Buscar por nome ou cargo", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                Spacer()
                Text("\(db.people.count) cadastrado(s)").foregroundStyle(.secondary)
            }
            .padding(16)

            if filtered.isEmpty {
                ContentUnavailableView {
                    Label("Nenhuma pessoa cadastrada", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("Use a aba Cadastrar para adicionar pessoas ao controle de acesso.")
                }
            } else {
                List {
                    ForEach(filtered) { person in
                        PersonRow(person: person, onToggleActive: {
                            var p = person; p.active.toggle(); db.updatePerson(p)
                        }, onDelete: { personPendingDelete = person })
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Pessoas cadastradas")
        .alert("Remover cadastro?", isPresented: .constant(personPendingDelete != nil), presenting: personPendingDelete) { person in
            Button("Cancelar", role: .cancel) { personPendingDelete = nil }
            Button("Remover", role: .destructive) {
                db.deletePerson(person.id)
                personPendingDelete = nil
            }
        } message: { person in
            Text("As \(person.embeddings.count) amostra(s) faciais de \(person.name) serão apagadas permanentemente.")
        }
    }
}

private struct PersonRow: View {
    let person: Person
    let onToggleActive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let img = ImageUtils.nsImage(from: person.embeddings.first?.thumbnailJPEG) {
                Image(nsImage: img).resizable().scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Circle().fill(Brand.card).frame(width: 44, height: 44)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.headline)
                Text(person.role.isEmpty ? person.accessLevel.label : "\(person.role) · \(person.accessLevel.label)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(person.embeddings.count) amostra(s)").font(.caption2).foregroundStyle(.secondary)

            Toggle("Ativo", isOn: Binding(get: { person.active }, set: { _ in onToggleActive() }))
                .toggleStyle(.switch).labelsHidden()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .opacity(person.active ? 1 : 0.45)
    }
}
