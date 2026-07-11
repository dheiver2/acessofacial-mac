import SwiftUI

struct AcessoFacialApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 980, minHeight: 620)
                .tint(Brand.accent)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1180, height: 760)
    }
}
