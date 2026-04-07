import Testing
@testable import KTalkAXMenuBarApp

struct ComposeDraftStateTests {
    @Test func whitespaceOnlyMessageStaysInvalid() {
        let state = ComposeDraftState(selectedChatID: "chat_1", chatName: "", message: "  \n  ", isBusy: false)
        #expect(state.trimmedMessage.isEmpty)
        #expect(state.canSubmit == false)
    }

    @Test func selectedChatAndTrimmedMessageEnableSubmit() {
        let state = ComposeDraftState(selectedChatID: "chat_1", chatName: "", message: "  hello world  ", isBusy: false)
        #expect(state.trimmedMessage == "hello world")
        #expect(state.canSubmit)
    }

    @Test func busyStateDisablesSubmitEvenWithDraft() {
        let state = ComposeDraftState(selectedChatID: "chat_1", chatName: "", message: "message", isBusy: true)
        #expect(state.canSubmit == false)
    }

    @Test func chatNameAndTrimmedMessageEnableSubmitWithoutSelection() {
        let state = ComposeDraftState(selectedChatID: nil, chatName: "이우린", message: "보낼 메시지", isBusy: false)
        #expect(state.trimmedChatName == "이우린")
        #expect(state.canSubmit)
    }
}
