@testable import IOSNavigationKit
import SwiftUI
import Testing

private enum TestToastKind: Sendable {
    case success
    case failure
}

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
        let toastStore = ToastStore<TestToastKind>()
        let otherToastStore = ToastStore<TestToastKind>()
        let toast = ToastMessage<TestToastKind>("Saved", kind: .success, duration: nil)
        let alert = AlertRequest(title: "Confirm")
        toastStore.showToast(toast)
        context.showAlert(alert)
        #expect(toastStore.toast?.id == toast.id)
        #expect(context.alert?.id == alert.id)
        #expect(otherToastStore.toast == nil && other.alert == nil)
        context.dismissAlert()
        #expect(toastStore.toast?.id == toast.id)
        context.showAlert(alert)
        #expect(context.alert?.id == alert.id)
    }

    @Test func toastMessageStoresAppDefinedKindAndDuration() {
        let toast = ToastMessage<TestToastKind>("Saved", kind: .success, duration: 4)
        #expect(toast.message == "Saved")
        #expect(toast.duration == 4)
        #expect(ToastMessage<TestToastKind>("Persistent", kind: .failure, duration: nil).duration == nil)
        let typedToast = ToastMessage<TestToastKind>("Typed", kind: .failure)
        #expect(typedToast.message == "Typed")
    }

    @Test func sharedPresentationsRemainIndependentOfLegacyRouter() {
        let context = PresentationContext()
        let router = PreviewRouter()
        let legacy = AlertPresentation(title: "Legacy")
        router.present(legacy)
        router.present(toast: .init(content: "Legacy toast", background: .green))
        let toastStore = ToastStore<TestToastKind>()
        let sharedToast = ToastMessage<TestToastKind>("Shared toast", kind: .success, duration: nil)
        let shared = AlertRequest(title: "Shared")
        context.showAlert(shared)
        toastStore.showToast(sharedToast)
        router.dismiss()
        #expect(router.alert == nil && router.toast != nil)
        #expect(context.alert?.id == shared.id && toastStore.toast?.id == sharedToast.id)
        router.dismissAllPresentations()
        #expect(context.alert?.id == shared.id && toastStore.toast?.id == sharedToast.id)
        router.present(legacy)
        context.dismissAlert()
        toastStore.dismissToast()
        #expect(router.alert?.id == legacy.id)
    }

    @Test func sharedToastSurvivesRouterModalDismissal() {
        let toastStore = ToastStore<TestToastKind>()
        let router = Router<Never, String, Never>()
        let toast = ToastMessage<TestToastKind>("Saved", kind: .success, duration: nil)

        toastStore.showToast(toast)
        router.presentSheet("modal")
        router.sheet = nil

        #expect(toastStore.toast?.id == toast.id)
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
        let toastStore = ToastStore<TestToastKind>(sleep: clock.sleep)
        toastStore.showToast(.init("First", kind: .success, duration: 2))
        while clock.pending.count < 1 { await Task.yield() }
        let replacement = ToastMessage<TestToastKind>("Second", kind: .failure, duration: 7)
        toastStore.showToast(replacement)
        while clock.pending.count < 2 { await Task.yield() }
        clock.finishFirst() // Deliberately ignores cancellation to exercise stale completion.
        await Task.yield()
        #expect(toastStore.toast?.id == replacement.id)
        clock.finishFirst()
        while toastStore.toast != nil { await Task.yield() }
        #expect(clock.durations == [2, 7])
    }

    @Test func reshowingSameToastRestartsTimer() async {
        let clock = ManualSleeper()
        let toastStore = ToastStore<TestToastKind>(sleep: clock.sleep)
        let toast = ToastMessage<TestToastKind>("Same", kind: .success)
        toastStore.showToast(toast)
        while clock.pending.count < 1 { await Task.yield() }
        toastStore.showToast(toast)
        while clock.pending.count < 2 { await Task.yield() }
        clock.finishFirst()
        await Task.yield()
        #expect(toastStore.toast?.id == toast.id)
        clock.finishFirst()
        while toastStore.toast != nil { await Task.yield() }
    }

    @Test func manualDismissalInvalidatesTimerAndStaleIDs() async {
        let clock = ManualSleeper()
        let toastStore = ToastStore<TestToastKind>(sleep: clock.sleep)
        let old = ToastMessage<TestToastKind>("Old", kind: .success)
        toastStore.showToast(old)
        while clock.pending.count < 1 { await Task.yield() }
        toastStore.dismissToast()
        let replacement = ToastMessage<TestToastKind>("Persistent", kind: .failure, duration: nil)
        toastStore.showToast(replacement)
        toastStore.dismissToast(id: old.id)
        clock.finishFirst()
        await Task.yield()
        #expect(toastStore.toast?.id == replacement.id)
    }

    @Test func persistentDurationsNeverSchedule() async {
        let clock = ManualSleeper()
        let toastStore = ToastStore<TestToastKind>(sleep: clock.sleep)
        for duration: TimeInterval? in [nil, 0, -1, .infinity, .nan] {
            toastStore.showToast(.init("Persistent", kind: .success, duration: duration))
            await Task.yield()
            #expect(toastStore.toast != nil)
        }
        #expect(clock.durations.isEmpty)
    }

    @Test func pendingTimerDoesNotRetainStore() async {
        let clock = ManualSleeper()
        var toastStore: ToastStore<TestToastKind>? = ToastStore(sleep: clock.sleep)
        let isReleased = { [weak toastStore] in toastStore == nil }
        toastStore?.showToast(.init("Temporary", kind: .success))
        while clock.pending.count < 1 { await Task.yield() }
        toastStore = nil
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
        nested.presentationContext.showAlert(.init(title: "Nested"))
        #expect(context.alert?.title == "Nested")
    }
}
