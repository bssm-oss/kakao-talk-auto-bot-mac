import Foundation

struct ComposeDraftState: Equatable {
    var selectedChatID: String?
    var message: String
    var isBusy: Bool

    var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        !isBusy && selectedChatID != nil && !trimmedMessage.isEmpty
    }
}
