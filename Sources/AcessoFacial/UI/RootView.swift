import SwiftUI

enum AppSection: String, Identifiable, CaseIterable {
    case monitor, cadastro, pessoas, registros, config
    var id: String { rawValue }
    var label: String {
        switch self {
        case .monitor: return "Monitor"
        case .cadastro: return "Cadastrar"
        case .pessoas: return "Pessoas"
        case .registros: return "Registros"
        case .config: return "Configurações"
        }
    }
    var icon: String {
        switch self {
        case .monitor: return "video.fill"
        case .cadastro: return "person.badge.plus"
        case .pessoas: return "person.2.fill"
        case .registros: return "clock.arrow.circlepath"
        case .config: return "gearshape.fill"
        }
    }
}

struct RootView: View {
    @StateObject private var db: FaceDatabase
    @StateObject private var camera: CameraController
    @StateObject private var monitorVM: MonitorViewModel
    @State private var selection: AppSection? = .monitor

    init() {
        let db = FaceDatabase()
        let camera = CameraController()
        _db = StateObject(wrappedValue: db)
        _camera = StateObject(wrappedValue: camera)
        _monitorVM = StateObject(wrappedValue: MonitorViewModel(camera: camera, db: db))
    }

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.label, systemImage: section.icon).tag(section)
            }
            .navigationSplitViewColumnWidth(200)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    BrandMark(size: 22)
                    Text("Acesso Facial").font(.headline)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        } detail: {
            switch selection ?? .monitor {
            case .monitor: MonitorView(vm: monitorVM)
            case .cadastro: EnrollView(camera: camera)
            case .pessoas: PeopleListView()
            case .registros: AccessLogView()
            case .config: SettingsView(camera: camera)
            }
        }
        .environmentObject(db)
        .onAppear { camera.requestAndStart() }
        .onDisappear { camera.stop() }
    }
}
