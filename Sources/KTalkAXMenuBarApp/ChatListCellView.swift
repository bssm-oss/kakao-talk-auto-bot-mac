import AppKit
import Foundation
import KTalkAXCore

@MainActor
final class ChatListCellView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("ChatListCellView")

    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(with chat: ChatSummaryResult) {
        titleLabel.stringValue = chat.title

        var details: [String] = []
        if let metaEstimate = chat.metaEstimate, !metaEstimate.isEmpty {
            details.append(metaEstimate)
        }
        if let unreadEstimate = chat.unreadEstimate {
            details.append("안읽음 \(unreadEstimate)")
        }
        details.append(chat.chatID)
        detailLabel.stringValue = details.joined(separator: " · ")
        toolTip = "\(chat.title)\n\(chat.chatID)"
    }

    private func setupViews() {
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail

        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle

        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
