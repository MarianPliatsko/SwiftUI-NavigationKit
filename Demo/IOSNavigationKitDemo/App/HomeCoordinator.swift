import IOSNavigationKit
import SwiftUI

@MainActor
struct HomeCoordinator: View {
    enum Push: Hashable { case details(Int) }
    enum Sheet: Hashable { case guide }
    enum Cover: Hashable { case workspace }

    @State private var router = Router<Push, Sheet, Cover>()

    var body: some View {
        NavigationContainer(router: router) {
            DemoPage(title: "Explore", subtitle: "One app. Independent journeys.", symbol: "safari") {
                DemoSection("Navigation") {
                    Button("Push detail screen") { router.push(.details(1)) }
                    Button("Present sheet") { router.presentSheet(.guide) }
                    Button("Open full-screen workspace") { router.presentFullScreenCover(.workspace) }
                }
                PresentationActions(source: "Explore")
                DemoSection("Try it") {
                    Text("Push a detail, switch to Profile, and push Settings. Switch back: each tab keeps its own stack.")
                    Text("Sheet: \(router.sheet == nil ? "dismissed" : "presented")")
                        .accessibilityIdentifier("home.sheetState")
                    Text("Workspace: \(router.fullScreenCover == nil ? "dismissed" : "presented")")
                }
            }
            .navigationTitle("Explore")
        } destination: { route in
            switch route {
            case .details(let number):
                DetailScreen(number: number, router: router)
            }
        } sheetDestination: { route in
            switch route {
            case .guide:
                ModalScreen(title: "Explore sheet")
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        } fullScreenDestination: { route in
            switch route {
            case .workspace:
                WorkspaceCoordinator()
            }
        }
    }
}

@MainActor
private struct DetailScreen: View {
    let number: Int
    let router: Router<HomeCoordinator.Push, HomeCoordinator.Sheet, HomeCoordinator.Cover>

    var body: some View {
        DemoPage(title: "Detail \(number)", subtitle: "A pushed screen shares the root presentations.", symbol: "square.stack") {
            DemoSection("Stack controls") {
                Text("Explore stack depth: \(router.path.count)")
                Button("Push another detail") { router.push(.details(number + 1)) }
                Button("Pop one screen") { router.pop() }
                Button("Pop to Explore root") { router.popToRoot() }
                Button("Open nested workspace") { router.presentFullScreenCover(.workspace) }
            }
            PresentationActions(source: "Detail \(number)")
            Text("You can also use the navigation bar's Back button or swipe from the leading edge.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Detail \(number)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
