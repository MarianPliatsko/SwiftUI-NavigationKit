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
    public func navigationPresentations<Kind: Sendable, ToastContent: View, AlertContent: View>(
        toastKind: Kind.Type,
        @ViewBuilder toast: @escaping (ToastMessage<Kind>) -> ToastContent,
        @ViewBuilder alert: @escaping (AlertRequest) -> AlertContent
    ) -> some View {
        modifier(NavigationPresentationsModifier(
            toastKind: toastKind,
            toastContent: toast,
            alertContent: alert
        ))
    }
}

@MainActor
private struct NavigationPresentationsModifier<Kind: Sendable, ToastContent: View, AlertContent: View>: ViewModifier {
    @Environment(\.installedPresentationContext) private var inheritedContext
    @State private var context = PresentationContext()
    @State private var toastStore: ToastStore<Kind>
    @State private var surfaces = PresentationSurfaces()

    let toastContent: (ToastMessage<Kind>) -> ToastContent
    let alertContent: (AlertRequest) -> AlertContent

    init(
        toastKind: Kind.Type,
        toastContent: @escaping (ToastMessage<Kind>) -> ToastContent,
        alertContent: @escaping (AlertRequest) -> AlertContent
    ) {
        _toastStore = State(initialValue: ToastStore<Kind>())
        self.toastContent = toastContent
        self.alertContent = alertContent
    }

    func body(content: Content) -> some View {
        if inheritedContext != nil {
            content
        } else {
            let renderers = PresentationRenderers(
                alert: { AnyView(alertContent($0)) }
            )
            content
                .modifier(PresentationHostModifier())
                .modifier(ToastWindowAttachment(
                    toastStore: toastStore,
                    toastContent: { AnyView(toastContent($0)) }
                ))
                .environment(\.installedPresentationContext, context)
                .environment(\.presentationSurfaces, surfaces)
                .environment(\.presentationRenderers, renderers)
                .environment(toastStore)
        }
    }
}

@MainActor
private struct ToastWindowAttachment<Kind: Sendable>: ViewModifier {
    let toastStore: ToastStore<Kind>
    let toastContent: @MainActor (ToastMessage<Kind>) -> AnyView

    func body(content: Content) -> some View {
#if os(iOS)
        content.overlay(alignment: .topLeading) {
            GlobalToastWindowHost(toastStore: toastStore, toastContent: toastContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
#else
        content
#endif
    }
}
