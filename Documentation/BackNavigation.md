# Back navigation investigation — 2026-10-22

## Reproduction and root cause

`NavigationContainer` always installs the compatibility `NavigationToastModifier`. That modifier attached `DragGesture(minimumDistance: 0)` to the entire navigation stack, even when `router.toast` was nil. The canonical demo uses the shared presentation context, so its legacy toast slots normally remain nil, but that whole-stack recognizer was still active.

On the iPhone 17 Pro Simulator running iOS 26.2, a UI test launched the unchanged demo, pushed Detail 1, tapped the native Back button once, and waited for the root screen. Back did not navigate. The same test passed on iOS 27.0. Router path mutation methods, the `@Bindable` NavigationStack binding, coordinator-owned `@State` routers, and the demo's contextual modal dismissal calls were inspected; none required changes.

Controlled experiments used a temporary copy of the package and app, a separate bundle identifier, and normal animation settings:

| iOS 26.2 variant | Result |
|---|---|
| Original whole-stack drag recognizer | First native Back tap failed |
| Same recognizer, skip redundant nil writes | First native Back tap still failed |
| Remove only the whole-stack recognizer | All four diagnostic UI tests passed |
| Keep the recognizer, disable it only while no legacy toast exists | All four diagnostic UI tests passed |

This isolates the regression to participation of the idle whole-stack gesture in native Back touch handling, rather than the redundant nil assignment. It does not establish the internal implementation details of SwiftUI/UIKit's recognizer arbitration. The temporary diagnostic tests covered repeated Back taps with and without a custom persistent toast, completed edge swipes, canceled edge swipes followed by Back, and independent tab/nested-modal stacks. Ordinary coordinate taps also worked in manual iOS 27 checks. Accessibility activation of the native Back element via the desktop automation tool was ineffective and was not used as evidence of the application bug.

## Minimal fix

Only `Sources/IOSNavigationKit/Compatibility/NavigationToastModifier.swift` changes in the library:

```swift
.simultaneousGesture(
    DragGesture(minimumDistance: 0).onChanged { _ in toast = nil },
    including: toast == nil ? .subviews : .all
)
```

SwiftUI's [`.subviews` mask](https://developer.apple.com/documentation/swiftui/gesturemask/subviews) disables the added gesture while retaining descendant gestures. When a legacy toast exists, `.all` retains its existing touch/drag-to-dismiss handling. No gesture can dismiss an absent toast, so the inactive case needs no toast recognizer. Shared custom presentation views continue to own their own interaction.

`Router.swift`, `NavigationContainer.swift`, modal bindings, route identity, coordinator source files, and the presentation context are unchanged. `Router.dismiss()` still matches the Novele implementation body exactly. There are no delays, repeated dismissal calls, disabled animations, navigation policies, or presentation-priority changes.

## Regression tests

The canonical app now has an `IOSNavigationKitDemoUITests` target, included in its shared scheme. `Demo/IOSNavigationKitDemo/UITests/NavigationUITests.swift` tests:

- Eight push/native-Back cycles, alternating with a persistent custom toast. Each cycle taps Back exactly once.
- Programmatic pop and pop to root, including subsequent pushes and path-depth checks.
- Completed interactive edge-swipe Back.
- Canceled interactive Back followed by one native Back tap, checking path depth.
- Independent tab histories and a nested workspace's Back navigation and contextual close.

These are application UI tests, outside all package targets. In Xcode, select the canonical demo scheme and Simulator, then press **⌘U**. Run against iOS 26.2 when available to exercise the OS version on which the original failure was reproduced. Expectation timeouts wait for UI observations; no production timing workaround is introduced.

At the time of this investigation, the root shared-presentation overlay could be obscured by native sheets/covers. The later scene-level Toast window implementation is documented in `Extraction.md`. Real-device touch behavior and accessibility remain useful additional smoke checks.

## Final validation

Using Xcode 27.0 / Apple Swift 6.4 on 2026-10-22:

| Check | Result |
|---|---|
| `swift build --package-path IOSNavigationKit` | Passed |
| `swift test --package-path IOSNavigationKit` | 22 tests passed, zero failures at this investigation |
| Canonical demo UI tests: iPhone 17 Pro, iOS 26.2 | All five passed, zero failures |
| Canonical demo UI tests: iPhone 18 Pro, iOS 27.0 | All five passed, zero failures |
| Canonical demo generic iOS Simulator SDK build, `ONLY_ACTIVE_ARCH=NO` | Passed for arm64 and x86_64 |
| Source checksum comparison | Only the compatibility toast modifier changed in the library; manifest, Router, and NavigationContainer unchanged |
| Direct `Router.dismiss()` comparison with Novele | Exact body match |
| Workspace Xcode project audit | Only `Demo/IOSNavigationKitDemo/IOSNavigationKitDemo.xcodeproj` remains active under the package |

Generated logs and results are under the package's ignored `.build/` directory:

- `BackNavigationInvestigation/ios26-{baseline,guard,no-gesture,mask}.log` records the controlled comparisons.
- `back-navigation-package-build.log` and `back-navigation-package-tests.log` record package validation.

## Follow-up shared Toast window validation

On 2026-10-22, the scene-level pass-through Toast window was verified on iPhone 17 Pro / iOS 26.2. The Toast stayed above a presented full-screen cover, remained visible after dismissal, accepted taps within its bounds, and passed touches outside its bounds through to the app. Bottom placement and configurable `bottomPadding` were included in the follow-up UI regression. The current package suite passes 25 tests.
- `back-navigation-ios26.log` / `.xcresult` and `back-navigation-ios27.log` / `.xcresult` record the canonical demo UI runs.
- `back-navigation-simulator-build.log` records the generic Simulator build.

Xcode emitted its App Intents metadata-extraction notice for targets without an App Intents dependency; no source compilation errors or warnings remained. The original sandbox restrictions on compiler caches, test services, and result export were resolved through approved tool access. No real-device testing was performed.
