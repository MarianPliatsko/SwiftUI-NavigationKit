import IOSNavigationKit
import SwiftUI
import Testing

private enum Push: Hashable { case details(Int), settings }
private enum Sheet: Hashable { case edit(Int), help }
private enum Cover: Hashable { case onboarding, profile(Int) }

@MainActor
struct RouterTests {
    private typealias TestRouter = Router<Push, Sheet, Cover>

    @Test func initialState() {
        let empty = TestRouter()
        #expect(empty.path.isEmpty)
        #expect(empty.sheet == nil && empty.fullScreenCover == nil)
        #expect(empty.alert == nil && empty.toast == nil)
        let alert = AlertPresentation(title: "Attention")
        let seeded = TestRouter(path: [.details(1)], sheet: .help, fullScreenCover: .onboarding, alert: alert)
        #expect(seeded.path == [.details(1)])
        #expect(seeded.sheet == .help)
        #expect(seeded.fullScreenCover == .onboarding)
        #expect(seeded.alert?.id == alert.id)
        #expect(seeded.toast == nil)
    }

    @Test func pathOrderDuplicatesAndPop() {
        let router = TestRouter()
        router.pop()
        router.push(.details(1))
        router.push(.settings)
        router.push(.details(1))
        #expect(router.path == [.details(1), .settings, .details(1)])
        router.pop()
        #expect(router.path == [.details(1), .settings])
        router.pop(1)
        #expect(router.path == [.details(1)])
        router.popToRoot()
        #expect(router.path.isEmpty)
        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test(arguments: [Int.min, -1, 0, 1, 2, 3, Int.max])
    func countedPopIsBounded(_ count: Int) {
        let router = TestRouter(path: [.details(1), .settings])
        router.pop(count)
        let remaining = count <= 0 ? 2 : max(0, 2 - min(count, 2))
        #expect(router.path == Array([Push.details(1), .settings].prefix(remaining)))
        let empty = TestRouter()
        empty.pop(count)
        #expect(empty.path.isEmpty)
    }

    @Test func presentationRequestsReplaceOnlyTheirOwnSlot() {
        let router = TestRouter(path: [.settings])
        let alert = AlertPresentation(title: "Alert")
        let toast = ToastData(content: "Saved", background: .green)
        router.presentSheet(.help)
        router.presentFullScreenCover(.onboarding)
        router.present(alert)
        router.present(toast: toast)
        router.presentSheet(.edit(2))
        router.presentFullScreenCover(.profile(3))
        #expect(router.sheet == .edit(2))
        #expect(router.fullScreenCover == .profile(3))
        #expect(router.alert?.id == alert.id)
        #expect(router.toast == toast)
        #expect(router.path == [.settings])
        let replacement = AlertPresentation(title: "Replacement")
        router.present(replacement)
        #expect(router.alert?.id == replacement.id)
    }

    // Exercise every combination, including multiple populated slots and no slots.
    @Test(arguments: Array(0..<8))
    func dismissClearsExactlyOneLocalSlot(_ mask: Int) {
        let hasAlert = mask & 1 != 0
        let hasSheet = mask & 2 != 0
        let hasCover = mask & 4 != 0
        let router = TestRouter(
            path: [.details(42)],
            sheet: hasSheet ? .help : nil,
            fullScreenCover: hasCover ? .onboarding : nil,
            alert: hasAlert ? .init(title: "Alert") : nil
        )
        let toast = ToastData(content: "Unchanged", background: .blue)
        router.present(toast: toast)
        router.dismiss()
        #expect(router.alert == nil)
        #expect(router.sheet == (hasSheet && hasAlert ? .help : nil))
        #expect(router.fullScreenCover == (hasCover && (hasAlert || hasSheet) ? .onboarding : nil))
        #expect(router.path == [.details(42)])
        #expect(router.toast == toast)
    }

    @Test func repeatedDismissalFollowsReferencePriority() {
        let router = TestRouter(sheet: .help, fullScreenCover: .onboarding, alert: .init(title: "Alert"))
        router.dismiss()
        #expect(router.alert == nil && router.sheet == .help && router.fullScreenCover == .onboarding)
        router.dismiss()
        #expect(router.sheet == nil && router.fullScreenCover == .onboarding)
        router.dismiss()
        #expect(router.fullScreenCover == nil)
        router.dismiss()
        #expect(router.path.isEmpty)
    }

    @Test func dismissAllRetainsPathAndOtherRouters() {
        let router = TestRouter(path: [.settings], sheet: .help, fullScreenCover: .onboarding, alert: .init(title: "Alert"))
        router.present(toast: .init(content: "Saved", background: .green))
        let nested = TestRouter(path: [.details(7)], sheet: .edit(7))
        router.dismissAllPresentations()
        #expect(router.sheet == nil && router.fullScreenCover == nil)
        #expect(router.alert == nil && router.toast == nil)
        #expect(router.path == [.settings])
        #expect(nested.path == [.details(7)] && nested.sheet == .edit(7))
    }

    @Test func writableStateSupportsSwiftUIWriteback() {
        let router = TestRouter(path: [.settings, .details(1)], sheet: .help, fullScreenCover: .onboarding)
        @Bindable var bindingRouter = router
        $bindingRouter.path.wrappedValue = [.settings]
        $bindingRouter.sheet.wrappedValue = nil
        $bindingRouter.fullScreenCover.wrappedValue = nil
        #expect(router.path == [.settings])
        #expect(router.sheet == nil && router.fullScreenCover == nil)
    }

    @Test func modalIdentityUsesWholeRoute() {
        struct Payload: Hashable { let id: Int; let title: String }
        let first = PresentedRoute(route: Payload(id: 1, title: "First"))
        let repeated = PresentedRoute(route: Payload(id: 1, title: "First"))
        let changed = PresentedRoute(route: Payload(id: 1, title: "Changed"))
        #expect(first.id == first.route)
        #expect(first.id == repeated.id)
        #expect(first.id != changed.id)
    }

    @Test func alertActionLimitAndCallback() {
        var calls = 0
        let action = AlertPresentation.Action.default("Continue") { calls += 1 }
        let alert = AlertPresentation(title: "Alert", actions: [action, .cancel("Cancel"), .destructive("Delete"), .default("Omitted")])
        #expect(alert.actions.count == 3)
        alert.actions[0].handler?()
        #expect(calls == 1)
        #expect(alert.actions[1].role == .cancel)
    }

    @Test func toastEqualityPreservesReferenceExclusions() {
        let first = ToastData(content: "Saved", background: .green)
        let restyled = ToastData(leadingContent: .loadingIndicator, content: "Saved", background: .blue)
        #expect(first == restyled)
        #expect(Set([first, restyled]).count == 1)
        #expect(first != ToastData(content: "Saved", background: .green, duration: nil))
    }

    @Test func aliasesAndProtocolArePubliclyUsable() {
        let unified = UnifiedRouter<Push>()
        func pushSettings<R: Routable>(_ router: R) where R.PushRoute == Push { router.push(.settings) }
        pushSettings(unified)
        #expect(unified.path == [.settings])
        let preview = PreviewRouter.previewValue
        #expect(preview.path.isEmpty)
    }
}
