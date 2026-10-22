import SwiftUI

extension EnvironmentValues {
    @Entry var installedPresentationContext: PresentationContext? = nil

    /// Requires a `navigationPresentations` modifier on an ancestor.
    public var presentationContext: PresentationContext {
        guard let context = installedPresentationContext else {
            preconditionFailure("Install .navigationPresentations at the application root before accessing presentationContext.")
        }
        return context
    }
}

extension View {
    /// Configures shared presentations once for this subtree.
    /// Nested installations reuse the ancestor's context and render no additional host;
    /// the ancestor's builders take precedence. Sibling installations are independent scopes.
    /// Shared Toasts render in a scene-level overlay window; alerts render on the active
    /// NavigationContainer surface.
    /// Presentations created outside this scope are outside this hosting scope.
    @MainActor
    public func navigationPresentations<ToastContent: View, AlertContent: View>(
        @ViewBuilder toast: @escaping (ToastMessage) -> ToastContent,
        @ViewBuilder alert: @escaping (AlertRequest) -> AlertContent
    ) -> some View {
        modifier(NavigationPresentationsModifier(toastContent: toast, alertContent: alert))
    }
}

@MainActor
private struct NavigationPresentationsModifier<ToastContent: View, AlertContent: View>: ViewModifier {
    @Environment(\.installedPresentationContext) private var inheritedContext
    @State private var context = PresentationContext()
    @State private var surfaces = PresentationSurfaces()

    let toastContent: (ToastMessage) -> ToastContent
    let alertContent: (AlertRequest) -> AlertContent

    func body(content: Content) -> some View {
        if inheritedContext != nil {
            content
        } else {
            let renderers = PresentationRenderers(
                toast: { AnyView(toastContent($0)) },
                alert: { AnyView(alertContent($0)) }
            )
            content
                .modifier(PresentationHostModifier())
                .modifier(ToastWindowAttachment(context: context, toastContent: renderers.toast))
                .environment(\.installedPresentationContext, context)
                .environment(\.presentationSurfaces, surfaces)
                .environment(\.presentationRenderers, renderers)
        }
    }
}

@MainActor
private struct ToastWindowAttachment: ViewModifier {
    let context: PresentationContext
    let toastContent: @MainActor (ToastMessage) -> AnyView

    func body(content: Content) -> some View {
#if os(iOS)
        content.overlay(alignment: .topLeading) {
            GlobalToastWindowHost(context: context, toastContent: toastContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
#else
        content
#endif
    }
}
