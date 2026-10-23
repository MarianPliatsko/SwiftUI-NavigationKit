import IOSNavigationKit
import SwiftUI

private enum ExampleToastKind: Sendable {
    case success
    case failure
}

#if os(iOS)
// Add @main when using this file in a standalone application target.
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .navigationPresentations(toastKind: ExampleToastKind.self) { toast in
                    CustomToastView(toast: toast)
                } alert: { alert in
                    CustomAlertView(alert: alert)
                }
        }
    }
}

private struct AppCoordinator: View {
    enum Route: Hashable { case profile }
    @State private var router = Router<Route, Never, Never>()

    var body: some View {
        NavigationContainer(router: router) {
            Button("Profile") { router.push(.profile) }
        } destination: { _ in
            ProfileCoordinator()
        }
    }
}

// A nested feature retains its own navigation router and inherits the root context.
// It installs no presentation modifier.
private struct ProfileCoordinator: View {
    enum Route: Hashable { case settings }
    @State private var router = Router<Route, Never, Never>()

    var body: some View {
        NavigationContainer(router: router) {
            ProfileScreen()
            Button("Settings") { router.push(.settings) }
        } destination: { _ in
            ProfileScreen() // The pushed screen also receives the same context.
        }
    }
}

private struct ProfileScreen: View {
    @Environment(\.presentationContext) private var presentation
    @Environment(ToastStore<ExampleToastKind>.self) private var toastStore

    var body: some View {
        VStack {
            Button("Save") {
                toastStore.showToast(.init("Profile updated", kind: .success))
            }
            Button("Delete") {
                presentation.showAlert(.init(
                    title: "Delete account?",
                    message: "This action cannot be undone.",
                    actions: [
                        .init(title: "Delete", role: .destructive) {
                            // A follow-up alert survives dismissal of the original request.
                            presentation.showAlert(.init(
                                title: "Account deleted",
                                actions: [.init(title: "OK")]
                            ))
                        },
                        .init(title: "Cancel", role: .cancel)
                    ]
                ))
            }
        }
    }
}
#endif

// All styling and interaction in these views belongs to the application.
private struct CustomToastView: View {
    let toast: ToastMessage<ExampleToastKind>
    @Environment(ToastStore<ExampleToastKind>.self) private var toastStore

    var body: some View {
        VStack {
            Spacer()
            Button { toastStore.dismissToast(id: toast.id) } label: {
                Text(toast.message)
                    .padding()
                    .background(.regularMaterial, in: .capsule)
            }
            .padding(.bottom, 32)
        }
    }
}

private struct CustomAlertView: View {
    let alert: AlertRequest
    @Environment(\.presentationContext) private var presentation

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(alert.title).font(.headline)
                if let message = alert.message { Text(message) }
                ForEach(alert.actions) { action in
                    Button(action.title, role: action.role) {
                        presentation.perform(action, for: alert)
                    }
                }
                if alert.actions.isEmpty {
                    Button("Close") { presentation.dismissAlert(id: alert.id) }
                }
            }
            .padding()
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .padding()
        }
    }
}
