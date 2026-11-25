import SwiftUI

@main
struct KasirApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
                .tint(Theme.blue3)
        }
    }
}
