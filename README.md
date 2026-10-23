# IOSNavigationKit

A dependency-free, feature-typed navigation package for SwiftUI applications. Requires Swift 6 and iOS 17+. Router state can also be built and tested on macOS 14+; `NavigationContainer` is iOS-only because it uses `fullScreenCover`.

## Install from GitHub

In Xcode, choose **File → Add Package Dependencies…**, enter `https://github.com/MarianPliatsko/IOSNavigationKit`, select the `main` branch, and add the `IOSNavigationKit` product. This repository is private, so collaborators must have GitHub access and authenticate Git operations through Xcode. For reproducible production dependencies, use a version tag when one is published.

For local development, add this directory as a local Swift package and link the `IOSNavigationKit` product.

## Demo App

The standalone demo app is kept outside this package repository, in the adjacent workspace folder `IOSNavigationKitDemo`. It links this package as a local dependency and includes UI regression tests. Demo sources and the Xcode project are not included in the library repository or Swift package.

The iOS 26.2 Back-navigation regression investigation and validation notes are in [BackNavigation.md](Documentation/BackNavigation.md).

## Minimal usage

The application owns its route enums, router lifetime, coordinator, and screen construction:

```swift
import IOSNavigationKit
import SwiftUI

@MainActor
struct ExampleCoordinator: View {
    enum Push: Hashable { case details(Int) }
    enum Sheet: Hashable { case help }
    enum Cover: Hashable { case welcome }

    @State private var router = Router<Push, Sheet, Cover>()

    var body: some View {
        NavigationContainer(router: router) {
            VStack {
                Button("Open details") { router.push(.details(42)) }
                Button("Help") { router.presentSheet(.help) }
                Button("Welcome") { router.presentFullScreenCover(.welcome) }
            }
        } destination: { route in
            switch route {
            case .details(let id): Text("Details: \(id)")
            }
        } sheetDestination: { route in
            switch route {
            case .help: Text("Help")
            }
        } fullScreenDestination: { route in
            switch route {
            case .welcome: WelcomeScreen()
            }
        }
    }
}

private struct WelcomeScreen: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button("Close welcome") { dismiss() }
    }
}
```

Use `Never` for unused channels. For example, `Router<Push, Never, Never>` needs only the `root` and `destination` builders. `UnifiedRouter<Route>` uses one route type and destination builder for every channel. `PreviewRouter.previewValue` creates an empty `Router<Never, Never, Never>`.

## App-level presentations

Define semantic toast kinds in the app. The generic kind flows through the toast model, store, and renderer, so the app's switch remains exhaustively checked at compile time:

```swift
enum AppToastKind: Sendable {
    case success
    case failure
}

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .navigationPresentations(toastKind: AppToastKind.self) { toast in
                    CustomToastView(toast: toast)
                } alert: { alert in
                    CustomAlertView(alert: alert)
                }
        }
    }
}
```

`ToastMessage<Kind>` contains a message, the app-defined `kind`, optional duration in seconds, and `bottomPadding` in points (default `50`). `Kind` must conform to `Sendable`; it need not be `Hashable` or `Equatable`. For example, `toastStore.showToast(.init("Saved", kind: .success, bottomPadding: 88))` places the Toast 88 points above the scene's bottom edge. The renderer receives the same typed `ToastMessage<AppToastKind>`, so switching over `toast.kind` is exhaustive. `AlertRequest` remains independent and contains a title, optional message, and unrestricted array of actions (title, optional SwiftUI `ButtonRole`, main-actor handler). Toast kinds carry semantic meaning only; the library does not prescribe colors, fonts, assets, or view content.

Both root builders must be supplied; return `EmptyView()` to intentionally omit a visual component. There is no default design. Builders receive the current request and may return any SwiftUI view. The alert view inherits the presentation context; the Toast view receives its typed `ToastStore<Kind>` in the environment.

A nested coordinator retains its independent router and installs no additional host:

```swift
struct ProfileCoordinator: View {
    enum Route: Hashable { case settings }
    @State private var router = Router<Route, Never, Never>()

    var body: some View {
        NavigationContainer(router: router) {
            ProfileScreen()
            Button("Settings") { router.push(.settings) }
        } destination: { _ in
            ProfileScreen()
        }
    }
}

struct ProfileScreen: View {
    @Environment(\.presentationContext) private var presentation
    @Environment(ToastStore<AppToastKind>.self) private var toastStore

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
                            // Delete account; optionally present a follow-up alert here.
                        },
                        .init(title: "Cancel", role: .cancel)
                    ]
                ))
            }
        }
    }
}

struct CustomToastView: View {
    let toast: ToastMessage<AppToastKind>
    @Environment(ToastStore<AppToastKind>.self) private var toastStore

    var body: some View {
        Button {
            toastStore.dismissToast(id: toast.id)
        } label: {
            HStack {
                switch toast.kind {
                case .success:
                    Image("ToastSuccess")
                case .failure:
                    Image("ToastFailure")
                }
                Text(toast.message)
            }
        }
    }
}
```

In a custom alert view, route buttons through the context to get guarded action execution and dismissal:

```swift
struct CustomAlertView: View {
    let alert: AlertRequest
    @Environment(\.presentationContext) private var presentation

    var body: some View {
        VStack {
            Text(alert.title)
            if let message = alert.message { Text(message) }
            ForEach(alert.actions) { action in
                Button(action.title, role: action.role) {
                    presentation.perform(action, for: alert)
                }
            }
            Button("Close") { presentation.dismissAlert(id: alert.id) }
        }
        // Apply your application's background, layout, and accessibility treatment.
    }
}
```

Calling an action's `handler` directly bypasses the context's lifecycle safeguards. A custom Toast can dismiss itself with `toastStore.dismissToast(id: toast.id)`. The complete, compiled [example](Examples/AppLevelPresentations.swift) includes application-owned toast and alert designs and two nested coordinators. The example target is built alongside the library; add `@main` when adopting its app in a standalone application target.

### Ownership and lifecycle

- The modifier owns a stable context for its SwiftUI identity. Descendants, pushed destinations, nested coordinators, and independent routers beneath it share that context through the environment. Context access without an ancestor host fails with a diagnostic; it never allocates a hidden fallback or global singleton.
- Nested modifier installations reuse the ancestor context and typed Toast store and omit their own host. The outermost builders take precedence; nested modifiers must use the same `Kind` as their ancestor. Separate sibling/window roots have separate scopes. Installing a new nested scope under an existing host is not supported in this version.
- Toast and alert slots are independent. Showing a request replaces only its own slot, with no queue, cross-slot dismissal, or router/modal arbitration. The application-owned Toast view renders in a scene-level pass-through window; custom alerts render on the active navigation/modal surface.
- Each toast show restarts timing, including reshowing the same value. Finite positive durations start at `showToast`, regardless of host visibility. Nil, nonpositive, and nonfinite durations persist. Replacement and explicit dismissal cancel the timer; stale completions cannot dismiss a replacement. A timer does not keep its store alive. Host disappearance alone does not clear retained state or pause timing; store lifetime follows the modifier's retained SwiftUI identity.
- Alert actions run synchronously on the main actor while the original request is current, then dismiss only that request by identity. A new alert shown by the action survives. Stale actions and actions belonging to a different request are ignored. Repeated taps after dismissal are ignored. Explicit alert dismissal runs no action. There is no implicit action or automatic dismissal for an alert with zero actions; the application supplies a close control.
- `ToastStore<Kind>.dismissToast()` and `PresentationContext.dismissAlert()` clear their respective current slots. Supplying `id:` makes dismissal conditional on that request still being current. New request values have distinct UUID identities; presenting the same alert value again retains its identity.
- Applications own toast styling, animations, focus management, VoiceOver behavior, and accessibility. The shared Toast host positions content near the bottom of the scene and uses the rendered content bounds for hit testing; touches elsewhere pass through to the app.

**Toast window:** on iOS, each outermost `.navigationPresentations` scope installs one transparent `UIWindow` in its containing scene, above app navigation windows and below system alerts. Shared Toasts render there continuously, including above nested navigation stacks, sheets, and full-screen covers; they do not hand off between presenters. The window passes touches through outside the toast's measured bounds. The typed Toast store and timer are unchanged; the window is removed with its hosting view.

**Alert and scene boundary:** custom shared alerts remain hosted on the deepest active `NavigationContainer` surface. Toast windows are scoped to the containing `UIWindowScene`; native content in that scene is covered, while windows in another scene have their own presentation scope. This implementation does not alter modal ownership or presentation policy.

### Compatibility and migration

All existing `Router` APIs, `Routable`, `ToastData`, `AlertPresentation`, and the local renderers remain available with their prior behavior. Their source lives under `Compatibility/`; source relocation does not change module imports. The shared presentation hosts do not bridge, suppress, or redirect legacy router state.

Migrate individual toast/alert call sites to `toastStore.showToast` / `presentation.showAlert` and provide app-owned designs at the root. Shared state is separate from router state: `Router.dismiss()` and `dismissAllPresentations()` affect only their existing local slots. Use `ToastStore<Kind>` and `PresentationContext` dismissal APIs for their respective shared presentations. Mixing shared and legacy requests may render both; no conflict policy is introduced.

The legacy `AlertPresentation` still retains only three actions and its native renderer still clears synchronously replaced alerts after invoking a handler. The new `AlertRequest` / `PresentationContext.perform` path supports unrestricted actions and preserves replacement alerts. Legacy toast appearance, equality, timing, and gesture dismissal remain unchanged.

## Preserved legacy router contract

- `path` is a writable typed array. Push permits duplicates; pop is bounded and nonpositive counts do nothing.
- Sheet, cover, alert, and toast slots are independent. Requests replace only their own slot, even when another is populated. There is no presentation arbitration.
- `dismiss()` clears one local slot, in order: alert, sheet, full-screen cover. It never pops, clears toast, delegates upward, or closes the containing flow. With no matching slot, it does nothing.
- `dismissAllPresentations()` clears sheet, cover, alert, and toast, retaining the path.
- Modal identity is the entire `Hashable` route value. Equal requests retain equal identity; no UUID presentation identity is introduced.
- Modal destinations are rendered directly. A nested coordinator may retain its own router and container. Closing its containing flow uses SwiftUI's contextual dismiss or an explicit presenter callback owned by the application.
- The container receives a router; it does not retain one in `@State`, inject environment keys, or create parent/child links. The application must retain a stable router.
- Alerts retain at most three actions. An action handler runs before the alert binding is cleared, including when that handler synchronously installs a replacement alert.
- Toast equality includes text, duration, and bottom padding, excluding background and leading content. Positive durations schedule dismissal; nil/nonpositive durations do not. Touch/drag clears the toast as in the reference.

Supply localized alert titles, messages, and action labels from the application. An alert with no actions uses SwiftUI's `"OK"` label; supply an explicit action when a particular localization is required. Toasts use standard SwiftUI text and progress styling in place of Novele's design system.

All router access and alert callbacks are main-actor isolated. Async feature work, lifecycle validity, persistence, environment injection, tab selection, and destination resolution remain application responsibilities. `Routable` preserves the reference protocol's scope (it does not expose toast); `NavigationContainer` hosts concrete `Router` instances.

## Validation

```sh
swift build
swift test
xcodebuild -scheme IOSNavigationKit \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/xcode CODE_SIGNING_ALLOWED=NO build
```

State tests cover shared-slot independence, isolated contexts, injected deterministic toast timing, cancellation, stale completions and callbacks, action membership, synchronous alert replacement, context release, and environment reference propagation, in addition to the original router tests. Compilation and state tests do not validate SwiftUI host rendering. Smoke-test nested host suppression, inherited context in actual modal trees, overlay placement, toast timing during navigation, touch handling, VoiceOver focus, and the documented native-modal visibility boundary on Simulator or device.

See [extraction notes](Documentation/Extraction.md) for reference sources, adaptations, complete file inventory, and validation limitations.
