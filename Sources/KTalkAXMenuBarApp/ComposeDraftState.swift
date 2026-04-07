import Foundation

struct ComposeDraftState: Equatable {
    var selectedChatID: String?
    var chatName: String
    var message: String
    var isBusy: Bool

    var trimmedChatName: String {
        chatName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        !isBusy && (selectedChatID != nil || !trimmedChatName.isEmpty) && !trimmedMessage.isEmpty
    }
}
