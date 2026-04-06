import Testing
@testable import KTalkAXMenuBarApp

struct ComposeDraftStateTests {
    @Test func whitespaceOnlyMessageStaysInvalid() {
        let state = ComposeDraftState(selectedChatID: "chat_1", message: "  \n  ", isBusy: false)
        #expect(state.trimmedMessage.isEmpty)
        #expect(state.canSubmit == false)
    }

    @Test func selectedChatAndTrimmedMessageEnableSubmit() {
        let state = ComposeDraftState(selectedChatID: "chat_1", message: "  hello world  ", isBusy: false)
        #expect(state.trimmedMessage == "hello world")
        #expect(state.canSubmit)
    }

    @Test func busyStateDisablesSubmitEvenWithDraft() {
        let state = ComposeDraftState(selectedChatID: "chat_1", message: "message", isBusy: true)
        #expect(state.canSubmit == false)
    }
}
