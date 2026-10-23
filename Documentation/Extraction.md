# Extraction notes

## Back navigation fix and demo consolidation — 2026-10-22

The earlier extraction/additive implementation notes below describe their original state. Subsequent controlled Simulator UI tests isolated an iOS 26.2 native Back failure to the compatibility toast modifier's always-active whole-stack drag recognizer. `NavigationToastModifier` now disables only the added gesture while its toast is nil, using `.subviews` to preserve descendant gestures. Its existing `.all` behavior remains while a legacy toast is present. Router and NavigationContainer source, dismissal semantics, and navigation/modal ownership are unchanged. See [BackNavigation.md](BackNavigation.md) for reproduction and tests.

The standalone demo and its application UI-test target live in a sibling workspace folder outside this package repository. The demo links this package through a local Swift package reference. No reference project or Knowledge Base files were changed.

## Scene-level shared Toast window — 2026-10-22

Shared app-level Toast now renders in a transparent pass-through `UIWindow` associated with the containing `UIWindowScene`. This keeps the same view continuously above nested navigation stacks and native modal presentations, without handing it between parent/child hosts. The window is above app content but below system alerts; hit testing passes through outside the measured toast content bounds. The library does not impose width or padding; each app controls Toast layout in its renderer. Custom shared alerts continue to render on the deepest active library-managed navigation/modal surface. Legacy router-local presentations are unchanged.

## App-defined typed Toast kinds

Shared Toast state is now held by `ToastStore<Kind: Sendable>`, separate from the alert-only `PresentationContext`. Apps define the semantic `Kind` enum and map it to app-owned assets/styles in the renderer. `ToastMessage<Kind>` carries that type through screen call sites, environment access, and rendering, enabling exhaustive compile-time switches without constraining kind cases to library-defined values. The root modifier takes `toastKind: Kind.Type` to establish the generic type. Alerts and router-local Toast APIs are unchanged.

## Additive app-level presentations — 2026-10-21

The original extraction below is historical. The approved additive implementation introduces a separate `PresentationContext`, design-free `ToastMessage` / `AlertRequest` models, and `.navigationPresentations(toast:alert:)`. The modifier owns one context and overlay host per root scope; nested installations inherit the outer scope and do not create another visible host. Application builders supply all new presentation visuals. There are no global stores, static mutable state, parent-router relationships, or additional window infrastructure.

`Sources/IOSNavigationKit/Presentation/` contains `PresentationContext.swift`, `ToastMessage.swift`, `AlertRequest.swift`, and `NavigationPresentations.swift`. Legacy `AlertPresentation.swift`, `ToastData.swift`, and `NavigationToastModifier.swift` moved unchanged into `Sources/IOSNavigationKit/Compatibility/`. `Router.swift`, `NavigationContainer.swift`, and `PresentedRoute.swift` remain unchanged. `Package.swift` adds a compiled examples target; `Examples/AppLevelPresentations.swift`, `Tests/IOSNavigationKitTests/PresentationContextTests.swift`, and the README document and exercise the new path.

Compatibility is additive: legacy router slots still render locally and retain their original semantics. No automatic bridging or client migration occurs. In particular, the new context's alert action execution uses request identity to preserve a synchronously installed replacement; this intentionally improved behavior applies only to the new API. The legacy native alert modifier remains unchanged. Shared presentation dismissal never calls router dismissal or changes modal ownership.

Toast timing begins when requested and remains independent of visual hosting. Replacement/dismissal cancels previous timing, with cancellation and generation checks guarding stale completions. A timer weakly captures its context. Finite positive durations expire automatically; nil, nonpositive, or nonfinite durations persist. Test-only internal sleep injection permits deterministic lifecycle checks. Applications own presentation appearance and interaction.

Toast rendering uses a UIKit window bridge on iOS; alert rendering remains a SwiftUI overlay. Actual window lifetime, touch passthrough, layout, accessibility, and interactions require Simulator/device validation.

Novele source and Knowledge Base documentation were read as evidence only and were not modified. ADR-001 / ADR-002 constrain the design without turning reference analyses into specifications. The existing feature-typed navigation architecture is preserved.

### Additive implementation validation

- Apple Swift 6.4, Xcode 27.0 (27A266a), Swift 6 language mode; iOS deployment target remains 17.0.
- `swift build --package-path IOSNavigationKit`: passed, including the examples target on macOS.
- `swift test --package-path IOSNavigationKit`: passed, 22 Swift Testing tests in two suites (12 existing router tests and 10 shared presentation tests), zero failures. Parameterized router tests additionally exercise seven pop counts and eight slot combinations. The XCTest preamble reports zero tests; the subsequent Swift Testing runner reports the actual results.
- `xcodebuild -scheme IOSNavigationKit -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/xcode CODE_SIGNING_ALLOWED=NO build` from the package directory: passed for arm64 and x86_64. Log: `.build/ios-simulator-build.log`.
- `swift build --package-path IOSNavigationKit --triple arm64-apple-ios17.0-simulator --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator27.0.sdk --target IOSNavigationKitExamples --scratch-path IOSNavigationKit/.build/example-ios`: passed, separately compiling the example's iOS-only nested coordinator and navigation code. Log: `.build/example-ios-build.log`.
- Direct comparison confirmed the `Router.dismiss()` body still matches Novele exactly.
- Initial sandboxed attempts could not access compiler caches / Xcode services; approved retries passed. No source errors remained and the final builds/tests produced no source warnings.
- No Simulator/device UI runtime tests were run. Environment reference propagation is unit tested; actual SwiftUI inheritance and duplicate-host suppression, timing while navigating, layout, interaction, VoiceOver, and native-modal visibility require the smoke testing described in the README.

## Authority and boundaries

Inspected Novele under `/Users/marianpliatsko/Documents/Work/Projects/novele-ios`. Read Knowledge Base README, ADR-001, ADR-002, and the Feature-typed Coordinator Routing analysis. The analysis is reference evidence; this task explicitly selects Novele's existing behavior where ADR implementation choices remain open. No Parent-linked Destination Routing implementation was used.

Novele files inspected:

- `novele-ios/Utils/Navigation/Router.swift`
- `novele-ios/Utils/Navigation/NavigationContainer.swift`
- `novele-ios/Utils/Navigation/PresentedRoute.swift`
- `novele-ios/Utils/Navigation/AlertPresentation.swift`
- `novele-ios/Utils/Navigation/View+Alert.swift`
- `novele-ios/Common/UI/ToastKit/ToastData.swift`
- `novele-ios/Common/UI/ToastKit/ToastModifier.swift`
- `novele-ios/Common/UI/ToastKit/ToastView.swift`
- `novele-ios/Common/UI/ToastKit/ToastDestination.swift`
- `novele-ios/Common/UI/ToastKit/GlobalToastStore.swift`
- `novele-ios/Features/Main/Tabs/Home/HomeCoordinator.swift`
- `novele-ios.xcodeproj/project.pbxproj` (deployment and isolation settings only)

Only reusable navigation state, hosting, and their necessary alert/toast support belong in this package. Route enums, coordinator views, destination resolution, feature environment keys, tab routers, global toast window/store, and product-specific alert/toast factories remain client responsibilities. Existing demo files in the workspace are untouched.

## Packaging adaptations and deviations

1. Exported reusable declarations, properties, methods, initializers, and reference convenience initializers with public access. Removed project headers and the empty router deinitializer.
2. Imported Observation explicitly. Isolated `Routable`, `NavigationContainer`, alert state/callbacks, and UI modifiers to `@MainActor`, without relying on Novele's target-wide default actor isolation. Router was already main-actor isolated. The toast's main-queue callback uses `MainActor.assumeIsolated` to express its executor contract to Swift 6.
3. Retained the exact `dismiss()` implementation body, including its checks and early returns. Other state transitions, typed array path, item-binding writeback, whole-route identity, and independent presentation slots retain reference behavior.
4. Retained generic alert state/actions and rendering. Excluded `FieldErrorView.Alert`, localization/service dependencies, and feature-specific factories. `Action.cancel` requires an explicit title; the empty-actions fallback is SwiftUI's `"OK"` label rather than Novele's localization accessor. Handler-before-clear ordering and the three-action limit are unchanged.
5. Retained toast state/data, equality, timing, gesture dismissal, layout, and animation. Replaced the asset-based spinning image with `ProgressView`, proprietary caption styling with `.caption.bold()`, and branded foreground color with `.primary`. Removed unused Kingfisher dependency and product previews. Toast rendering is internal to the container; no global toast subsystem or unrelated UI helpers were extracted. The reference container supplies no toast on-disappear callback, so none is added.
6. Selected Swift tools/language mode 6.0, iOS 17 (Observation foundation), and macOS 14 for host-side state tests. The iOS container is conditionally compiled on iOS only; no macOS full-screen-cover substitute changes its semantics.

These adaptations remove application dependencies and make isolation/public access explicit. No presentation priority, ownership, conflict policy, identity strategy, or dismissal rule was redesigned. Existing limitations remain: independent slots may compete in SwiftUI; routers do not close containing flows; equal modal routes share identity; synchronous alert replacement is cleared after an action. These are preserved contracts, not newly introduced policies.

## Created files

- `.gitignore`
- `Package.swift`
- `README.md`
- `Documentation/Extraction.md`
- `Sources/IOSNavigationKit/Router.swift`
- `Sources/IOSNavigationKit/NavigationContainer.swift`
- `Sources/IOSNavigationKit/PresentedRoute.swift`
- `Sources/IOSNavigationKit/AlertPresentation.swift`
- `Sources/IOSNavigationKit/ToastData.swift`
- `Sources/IOSNavigationKit/NavigationToastModifier.swift`
- `Tests/IOSNavigationKitTests/RouterTests.swift`

Build tools also generate ignored `.build/` artifacts. No client project or Knowledge Base files are modified.

## Runtime verification boundary

State tests exercise navigation and dismissal without running a SwiftUI interface. They cannot establish modal animation order, equal-identity visible replacement, interactive sheet/cover dismissal, nested presentation behavior, or toast timing/appearance on a device. These require an iOS UI smoke test. No runtime presentation behavior is claimed from compilation alone.

## Validation results — 2026-10-21

- Toolchain: Apple Swift 6.4, Xcode 27.0 (27A266a), package compiled in Swift 6 language mode.
- `swift build --package-path IOSNavigationKit`: passed on macOS after granting access to compiler caches. The initial sandboxed attempt failed to access the Clang module cache; it was not a source compilation failure.
- `swift test --package-path IOSNavigationKit`: passed, 12 Swift Testing tests, zero failures. Parameterized tests cover seven pop counts and all eight presentation-slot combinations. The preliminary XCTest runner reports zero tests because these tests use Swift Testing; the Swift Testing runner reports all 12 passing.
- iOS Simulator SDK build: passed for arm64 and x86_64, deployment target iOS 17.0, signing disabled. Xcode printed a supported-destinations discovery diagnostic, then successfully built both architectures. No source compilation errors remained.
- Direct text comparison confirmed that the extracted `dismiss()` body matches Novele exactly.
- No iOS UI runtime tests or device tests were run. Swift 6.0 is the manifest minimum; validation used the installed Swift 6.4 compiler.
