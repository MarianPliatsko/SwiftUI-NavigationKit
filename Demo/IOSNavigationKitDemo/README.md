# IOSNavigationKit Demo

A standalone SwiftUI iPhone/iPad application for iOS 17+, using Swift 6 and no external dependencies.

## Launch from Xcode

1. Open `IOSNavigationKitDemo.xcodeproj` in this directory. This is the workspace's only maintained demo project; the older parent-level demo is archived.
2. Select the shared **IOSNavigationKitDemo** scheme and an available iPhone or iPad Simulator.
3. Press **⌘R**. No development team is required for Simulator. A physical device requires your own signing team.

The project references the repository root as a local Swift package at `../..` and links its `IOSNavigationKit` library product. Keep the demo at this relative location. The demo's `App/` files belong only to the Xcode application target, outside the package's `Sources/` and `Examples/` targets. No library code is duplicated into the application.

## What to try

1. In **Explore**, tap **Push detail screen**, then **Push another detail**. Try explicit pop, pop to root, the Back button, and the leading-edge back gesture.
2. Leave Explore on a detail screen. Switch to **Profile**, push **Settings**, then **Preferences**. Switch tabs to verify both typed routers retain independent histories.
3. From a pushed screen, show a 3-second toast, a persistent toast, or the replacement alert demo. Tap **Continue**: the replacement alert stays visible. Tap **Finish** to show a toast. Tap a toast to dismiss it.
4. From Explore, present a sheet. Swipe it down using the grabber, check **Sheet: dismissed**, then reopen it. Profile has its own independent sheet. **Dismiss sheet** uses SwiftUI's contextual dismissal.
5. Open the full-screen **Workspace**. It is a nested coordinator with a third typed router. Push items, pop, and present its nested sheet. Swipe down to dismiss the sheet and check the workspace's sheet status. Use **Done** / **Close workspace** to close the full-screen flow and return to the original Explore path.
6. In a sheet, Workspace, and a pushed Workspace item, choose **Show persistent toast**. Verify it appears above the entire active scene, including native modals. Close the modal and verify the same Toast stays visible without moving between hosts. Tap it to dismiss. Choose **Show replacement alert demo**, then **Continue** and verify the replacement remains in the shared context; **Finish** shows a toast. Repeat in Workspace's nested sheet.

`IOSNavigationKitDemoApp.swift` configures presentations once at application level. `PresentationViews.swift` owns the custom `ToastView` and `AlertView`, including all styling and interaction. `PresentationActions` reads the shared context directly from feature screens. Alert buttons call `presentation.perform(action, for: alert)` so a synchronous replacement is preserved. Coordinators keep destination construction and modal ownership local; the shared Toast is rendered in a scene-level window.

## Presentation boundary

The shared Toast uses one transparent pass-through `UIWindow` per scene, so it remains continuously visible above nested NavigationStacks, sheets, and full-screen covers rather than switching between their overlays. It is anchored to the bottom edge; `ToastMessage(bottomPadding:)` configures its offset in points (default 50). Its timer and request identity persist independently of presentation transitions. Custom shared alerts still render on the deepest library-managed navigation/modal surface. Full-screen covers use an explicit close button; the native swipe-to-dismiss demonstration applies to sheets, and the back gesture applies to pushed destinations.

## Build from the repository root

```sh
xcodebuild \
  -project Demo/IOSNavigationKitDemo/IOSNavigationKitDemo.xcodeproj \
  -scheme IOSNavigationKitDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/demo \
  CODE_SIGNING_ALLOWED=NO build
```

Runtime smoke checks should include the steps above, landscape and iPad layout, large Dynamic Type, toast hit testing, and VoiceOver focus when one alert replaces another. An SDK build alone does not verify those behaviors.

## Validation

On 2026-10-21, the command above passed with Xcode 27.0 / Apple Swift 6.4 for both arm64 and x86_64 iOS Simulator architectures, targeting iOS 17. The build log is generated at `.build/demo-build.log` in the repository root. Xcode emitted an informational App Intents metadata-extraction warning because this demo has no App Intents dependency; there were no source compilation warnings or errors.

Library and manifest checksums were unchanged after that initial integration. Build source lists confirmed that only the six `App/` Swift files belong to the demo target and that no demo source enters the library target. At that initial validation, UI interaction smoke testing had not been performed. Subsequent Back navigation UI testing is described below.

At the initial integration, `swift test --package-path IOSNavigationKit` passed all 22 package tests. Current validation is recorded in the latest section below.

## Back navigation regression tests

The shared **IOSNavigationKitDemo** scheme now includes **IOSNavigationKitDemoUITests**. Select a Simulator and press **⌘U**. Tests exercise one-tap native Back, programmatic pop/pop to root, completed and canceled interactive Back gestures, persistent custom toasts, independent tabs, nested workspace navigation, and shared Toast visibility above a full-screen cover.

The original failure was reproduced on iOS 26.2: an idle legacy toast drag recognizer attached to the whole NavigationStack consumed the native Back interaction. The fix disables only that added gesture when no legacy toast exists, preserving descendant gestures and legacy toast dismissal when a toast is present. No Router or NavigationStack state changes were needed. See the [investigation and controlled comparisons](../../Documentation/BackNavigation.md).

On 2026-10-22, the original five UI tests passed on both iPhone 17 Pro / iOS 26.2 and iPhone 18 Pro / iOS 27.0. A later full-screen Toast UI regression also passed on iPhone 17 Pro / iOS 26.2; all 25 package tests pass after adding bottom-padding configuration. Real-device interaction, multi-scene behavior, landscape and iPad layout, Dynamic Type, and VoiceOver still merit smoke testing.

From the repository root, replace the example destination with a Simulator installed on your machine:

```sh
xcodebuild \
  -project Demo/IOSNavigationKitDemo/IOSNavigationKitDemo.xcodeproj \
  -scheme IOSNavigationKitDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -derivedDataPath .build/demo \
  CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO test
```
