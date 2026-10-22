@testable import IOSNavigationKit
import SwiftUI
import Testing

@MainActor
private final class ManualSleeper {
    var durations: [TimeInterval] = []
    var pending: [CheckedContinuation<Void, any Error>] = []

    func sleep(_ duration: TimeInterval) async throws {
        durations.append(duration)
        try await withCheckedThrowingContinuation { pending.append($0) }
    }

    func finishFirst() { pending.removeFirst().resume() }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PresentationContextTests {
    @Test func independentSlotsAndScopes() {
        let context = PresentationContext()
        let other = PresentationContext()
        let toast = ToastMessage("Saved", duration: nil)
        let alert = AlertRequest(title: "Confirm")
        context.showToast(toast)
        context.showAlert(alert)
        #expect(context.toast?.id == toast.id)
        #expect(context.alert?.id == alert.id)
        #expect(other.toast == nil && other.alert == nil)
        context.dismissAlert()
        #expect(context.toast?.id == toast.id)
        context.showAlert(alert)
        context.dismissToast()
        #expect(context.alert?.id == alert.id)
    }

    @Test func toastMessageStoresConfigurableBottomPadding() {
        #expect(ToastMessage("Default").bottomPadding == 50)
        #expect(ToastMessage("Custom", bottomPadding: 96).bottomPadding == 96)
    }

    @Test func sharedPresentationsRemainIndependentOfLegacyRouter() {
        let context = PresentationContext()
        let router = PreviewRouter()
        let legacy = AlertPresentation(title: "Legacy")
        router.present(legacy)
        router.present(toast: .init(content: "Legacy toast", background: .green))
        let shared = AlertRequest(title: "Shared")
        context.showAlert(shared)
        context.showToast(.init("Shared toast", duration: nil))
        router.dismiss()
        #expect(router.alert == nil && router.toast != nil)
        #expect(context.alert?.id == shared.id && context.toast != nil)
        router.dismissAllPresentations()
        #expect(context.alert?.id == shared.id && context.toast != nil)
        router.present(legacy)
        context.dismissAlert()
        context.dismissToast()
        #expect(router.alert?.id == legacy.id)
    }

    @Test func sharedToastSurvivesRouterModalDismissal() {
        let context = PresentationContext()
        let router = Router<Never, String, Never>()
        let toast = ToastMessage("Saved", duration: nil)

        context.showToast(toast)
        router.presentSheet("modal")
        router.sheet = nil

        #expect(context.toast?.id == toast.id)
    }

    @Test func alertActionPreservesSynchronousReplacement() {
        let context = PresentationContext()
        let replacement = AlertRequest(title: "Next")
        var calls = 0
        let action = AlertRequest.Action(title: "Continue") {
            #expect(context.alert != nil) // Handler runs before dismissal.
            calls += 1
            context.showAlert(replacement)
        }
        let original = AlertRequest(title: "First", actions: [action])
        context.showAlert(original)
        context.perform(action, for: original)
        #expect(calls == 1)
        #expect(context.alert?.id == replacement.id)
        context.perform(action, for: original)
        context.dismissAlert(id: original.id)
        #expect(calls == 1)
        #expect(context.alert?.id == replacement.id)
    }

    @Test func actionsDismissOnlyTheirRequestAndValidateMembership() {
        let context = PresentationContext()
        var calls = 0
        let action = AlertRequest.Action(title: "Delete", role: .destructive) { calls += 1 }
        let request = AlertRequest(title: "Confirm", actions: [action])
        context.showAlert(request)
        context.perform(.init(title: "Foreign") { calls += 100 }, for: request)
        #expect(calls == 0 && context.alert?.id == request.id)
        context.perform(action, for: request)
        context.perform(action, for: request)
        #expect(calls == 1 && context.alert == nil)
        context.showAlert(request)
        context.dismissAlert()
        #expect(calls == 1)
        let many = AlertRequest(title: "Custom", actions: (0..<5).map { .init(title: "\($0)") })
        #expect(many.actions.count == 5)
        #expect(action.role == .destructive)
    }

    @Test func timerExpiresAndReplacementCancelsStaleCompletion() async {
        let clock = ManualSleeper()
        let context = PresentationContext(sleep: clock.sleep)
        context.showToast(.init("First", duration: 2))
        while clock.pending.count < 1 { await Task.yield() }
        let replacement = ToastMessage("Second", duration: 7)
        context.showToast(replacement)
        while clock.pending.count < 2 { await Task.yield() }
        clock.finishFirst() // Deliberately ignores cancellation to exercise stale completion.
        await Task.yield()
        #expect(context.toast?.id == replacement.id)
        clock.finishFirst()
        while context.toast != nil { await Task.yield() }
        #expect(clock.durations == [2, 7])
    }

    @Test func reshowingSameToastRestartsTimer() async {
        let clock = ManualSleeper()
        let context = PresentationContext(sleep: clock.sleep)
        let toast = ToastMessage("Same")
        context.showToast(toast)
        while clock.pending.count < 1 { await Task.yield() }
        context.showToast(toast)
        while clock.pending.count < 2 { await Task.yield() }
        clock.finishFirst()
        await Task.yield()
        #expect(context.toast?.id == toast.id)
        clock.finishFirst()
        while context.toast != nil { await Task.yield() }
    }

    @Test func manualDismissalInvalidatesTimerAndStaleIDs() async {
        let clock = ManualSleeper()
        let context = PresentationContext(sleep: clock.sleep)
        let old = ToastMessage("Old")
        context.showToast(old)
        while clock.pending.count < 1 { await Task.yield() }
        context.dismissToast()
        let replacement = ToastMessage("Persistent", duration: nil)
        context.showToast(replacement)
        context.dismissToast(id: old.id)
        clock.finishFirst()
        await Task.yield()
        #expect(context.toast?.id == replacement.id)
    }

    @Test func persistentDurationsNeverSchedule() async {
        let clock = ManualSleeper()
        let context = PresentationContext(sleep: clock.sleep)
        for duration: TimeInterval? in [nil, 0, -1, .infinity, .nan] {
            context.showToast(.init("Persistent", duration: duration))
            await Task.yield()
            #expect(context.toast != nil)
        }
        #expect(clock.durations.isEmpty)
    }

    @Test func pendingTimerDoesNotRetainContext() async {
        let clock = ManualSleeper()
        var context: PresentationContext? = PresentationContext(sleep: clock.sleep)
        let isReleased = { [weak context] in context == nil }
        context?.showToast(.init("Temporary"))
        while clock.pending.count < 1 { await Task.yield() }
        context = nil
        #expect(isReleased())
        clock.finishFirst()
    }

    @Test func environmentCarriesSameReferenceAcrossCopies() {
        let context = PresentationContext()
        var root = EnvironmentValues()
        #expect(root.installedPresentationContext == nil)
        root.installedPresentationContext = context
        let nested = root
        #expect(root.presentationContext === nested.presentationContext)
        nested.presentationContext.showToast(.init("Nested", duration: nil))
        #expect(context.toast?.message == "Nested")
    }
}
