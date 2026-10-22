import Observation
import SwiftUI

// Type erasure is confined to the environment bridge: modal containers do not know
// the application's concrete presentation view types.
struct PresentationRenderers {
    let toast: @MainActor (ToastMessage) -> AnyView
    let alert: @MainActor (AlertRequest) -> AnyView
}

extension EnvironmentValues {
    @Entry var presentationRenderers: PresentationRenderers? = nil
    @Entry var presentationSurfaces: PresentationSurfaces? = nil
    @Entry var presentationSurfaceDepth: Int = -1
}

/// Rendering metadata only. The deepest appeared host renders shared presentations.
@MainActor
@Observable
final class PresentationSurfaces {
    private struct Surface {
        let id: UUID
        let depth: Int
    }

    private var surfaces: [Surface] = []

    var activeID: UUID? {
        guard let depth = surfaces.map(\.depth).max() else { return nil }
        return surfaces.last(where: { $0.depth == depth })?.id
    }

    func appear(id: UUID, depth: Int) {
        guard !surfaces.contains(where: { $0.id == id }) else { return }
        surfaces.append(Surface(id: id, depth: depth))
    }

    func disappear(id: UUID) {
        surfaces.removeAll(where: { $0.id == id })
    }
}

/// Installed at the scope root and at each NavigationContainer/modal boundary.
@MainActor
struct PresentationHostModifier: ViewModifier {
    @Environment(\.installedPresentationContext) private var context
    @Environment(\.presentationRenderers) private var renderers
    @Environment(\.presentationSurfaces) private var surfaces
    @Environment(\.presentationSurfaceDepth) private var parentDepth
    @State private var id = UUID()

    func body(content: Content) -> some View {
        if let context, let renderers, let surfaces {
            content
                .overlay {
                    if surfaces.activeID == id, let alert = context.alert {
                        renderers.alert(alert).id(alert.id)
                    }
                }
                .environment(\.presentationSurfaceDepth, parentDepth + 1)
                .onAppear { surfaces.appear(id: id, depth: parentDepth + 1) }
                .onDisappear { surfaces.disappear(id: id) }
        } else {
            // Existing clients without app-level configuration retain their behavior.
            content
        }
    }
}
