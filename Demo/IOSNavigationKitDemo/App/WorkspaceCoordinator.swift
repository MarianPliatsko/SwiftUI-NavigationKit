import IOSNavigationKit
import SwiftUI

/// A nested modal flow owns a separate router, while inheriting the root context.
@MainActor
struct WorkspaceCoordinator: View {
    enum Push: Hashable { case item(Int) }
    enum Sheet: Hashable { case notes }

    @State private var router = Router<Push, Sheet, Never>()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationContainer(router: router) {
            DemoPage(title: "Workspace", subtitle: "A full-screen flow with its own navigation.", symbol: "square.grid.2x2") {
                DemoSection("Nested navigation") {
                    Button("Push workspace item") { router.push(.item(1)) }
                    Button("Present nested sheet") { router.presentSheet(.notes) }
                    Text("Nested sheet: \(router.sheet == nil ? "dismissed" : "presented")")
                    Button("Close workspace") { dismiss() }
                }
                PresentationActions(source: "Workspace")
            }
            .navigationTitle("Workspace")
        } destination: { route in
            switch route {
            case .item(let number):
                DemoPage(title: "Workspace item \(number)", subtitle: "This path belongs only to the workspace.", symbol: "doc.text") {
                    DemoSection("Nested controls") {
                        Button("Push next workspace item") { router.push(.item(number + 1)) }
                        Button("Pop workspace item") { router.pop() }
                        Button("Pop to workspace root") { router.popToRoot() }
                        Button("Present nested sheet") { router.presentSheet(.notes) }
                    }
                    PresentationActions(source: "Workspace item \(number)")
                }
                .navigationTitle("Item \(number)")
            }
        } sheetDestination: { route in
            switch route {
            case .notes:
                ModalScreen(title: "Workspace notes")
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        // SwiftUI's contextual dismiss closes the containing flow; the local router
        // only manages the workspace's own path and presentation slots.
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

@MainActor
struct ModalScreen: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationContext) private var presentation

    var body: some View {
        DemoPage(title: title, subtitle: "Swipe down to dismiss this sheet.", symbol: "rectangle.bottomthird.inset.filled") {
            DemoSection("Interactive dismissal") {
                Text("Drag the grabber down, then present the sheet again. The presenter receives the dismissed state.")
                Button("Dismiss sheet") { dismiss() }
                Button("Leave a toast for the root, then close") {
                    presentation.showToast(.init("Requested from \(title)", duration: nil))
                    dismiss()
                }
            }
            PresentationActions(source: title)
        }
    }
}
