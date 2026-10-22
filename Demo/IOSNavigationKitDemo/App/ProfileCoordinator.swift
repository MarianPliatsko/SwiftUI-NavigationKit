import IOSNavigationKit
import SwiftUI

@MainActor
struct ProfileCoordinator: View {
    enum Push: Hashable { case settings, preferences }
    enum Sheet: Hashable { case about }

    @State private var router = Router<Push, Sheet, Never>()

    var body: some View {
        NavigationContainer(router: router) {
            DemoPage(title: "Profile", subtitle: "A second router. The same presentation scope.", symbol: "person.crop.circle") {
                DemoSection("Your space") {
                    Button("Push Settings") { router.push(.settings) }
                    Button("Present About sheet") { router.presentSheet(.about) }
                    Text("Profile sheet: \(router.sheet == nil ? "dismissed" : "presented")")
                }
                PresentationActions(source: "Profile")
            }
            .navigationTitle("Profile")
        } destination: { route in
            switch route {
            case .settings:
                DemoPage(title: "Settings", subtitle: "Explore's stack stays where you left it.", symbol: "slider.horizontal.3") {
                    DemoSection("Profile navigation") {
                        Button("Push Preferences") { router.push(.preferences) }
                        Button("Pop Settings") { router.pop() }
                    }
                    PresentationActions(source: "Settings")
                }
                .navigationTitle("Settings")
            case .preferences:
                DemoPage(title: "Preferences", subtitle: "Two levels deep in the Profile tab.", symbol: "switch.2") {
                    DemoSection("Return") {
                        Button("Pop one screen") { router.pop() }
                        Button("Pop to Profile root") { router.popToRoot() }
                    }
                    PresentationActions(source: "Preferences")
                }
                .navigationTitle("Preferences")
            }
        } sheetDestination: { route in
            switch route {
            case .about:
                ModalScreen(title: "Profile sheet")
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}
