import IOSNavigationKit
import SwiftUI

@main
@MainActor
struct IOSNavigationKitDemoApp: App {
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .tint(.indigo)
                // Configure once; shared Toasts render above native presentations.
                .navigationPresentations { toast in
                    ToastView(toast: toast)
                } alert: { alert in
                    AlertView(alert: alert)
                }
        }
    }
}

@MainActor
struct AppCoordinator: View {
    var body: some View {
        TabView {
            HomeCoordinator()
                .tabItem { Label("Explore", systemImage: "safari") }
            ProfileCoordinator()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
