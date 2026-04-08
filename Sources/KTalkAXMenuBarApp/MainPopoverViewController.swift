import AppKit
import ApplicationServices
@preconcurrency import Foundation
import KTalkAXCore

@MainActor
final class MainPopoverViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate, NSTextFieldDelegate {
    var onOpenSettings: (() -> Void)?
    var onStatusAppearanceChange: ((MenuBarStatusItemAppearance, StatusResult?) -> Void)?

    private enum RefreshTrigger {
        case popover
        case manual
        case promptForTrust
    }

    private enum FeedbackKind {
        case info
        case success
        case warning
        case error
    }

    private struct RefreshSnapshot {
        let status: StatusResult
        let chats: [ChatSummaryResult]
        let chatsError: Error?
    }

    private let service: KTalkAXService
    private let preferences: AppPreferences
    private let aiDraftWorkflow: AIDraftWorkflow

    private var chats: [ChatSummaryResult] = []
    private var latestStatus: StatusResult?
    private var selectedChatID: String?
    private var availableAIProviders: [AIProviderKind] = []
    private var aiConversation: [AIChatTurn] = []
    private var hasLoadedOnce = false
    private var hasTriggeredPermissionPrompt = false
    private var backgroundWorkBoxes: [BackgroundWorkBox] = []
    private var aiTask: Task<Void, Never>?
    private var isBusy = false {
        didSet {
            updateUIState()
            publishStatusAppearance()
        }
    }

    private let headerTitleLabel = NSTextField(labelWithString: "카카오톡 자동화")
    private let statusIconView = NSImageView()
    private let statusHeadlineLabel = NSTextField(labelWithString: "카카오톡 상태를 확인하는 중…")
    private let statusDetailLabel = NSTextField(labelWithString: "메뉴 막대 앱은 공유된 KTalkAXService를 직접 사용합니다.")
    private let refreshButton = NSButton(title: "", target: nil, action: nil)
    private let requestAccessButton = NSButton(title: "권한 요청", target: nil, action: nil)
    private let progressIndicator = NSProgressIndicator()
    private let chatCountLabel = NSTextField(labelWithString: "보이는 채팅방")
    private let roomNameLabel = NSTextField(labelWithString: "채팅방")
    private let roomNameField = NSTextField(string: "")
    private let messageLabel = NSTextField(labelWithString: "메시지")
    private let emptyStateLabel = NSTextField(labelWithString: "아직 불러온 채팅방이 없습니다.")
    private let selectionLabel = NSTextField(labelWithString: "채팅방 이름을 직접 입력하거나, 아래 목록에서 선택할 수 있습니다.")
    private let aiProviderLabel = NSTextField(labelWithString: "")
    private let feedbackLabel = NSTextField(labelWithString: "")
    private let chatsTableView = NSTableView()
    private let aiConversationTextView = NSTextView(frame: .zero)
    private let aiPromptField = NSTextField(string: "")
    private let messageTextView = NSTextView(frame: .zero)
    private let aiAskButton = NSButton(title: "AI에게 묻기", target: nil, action: nil)
    private let aiUseReplyButton = NSButton(title: "마지막 답변 적용", target: nil, action: nil)
    private let aiDraftButton = NSButton(title: "AI 초안", target: nil, action: nil)
    private let aiRewriteButton = NSButton(title: "AI로 다듬기", target: nil, action: nil)
    private let dryRunButton = NSButton(title: "드라이런", target: nil, action: nil)
    private let sendButton = NSButton(title: "전송", target: nil, action: nil)

    init(service: KTalkAXService, preferences: AppPreferences, aiDraftWorkflow: AIDraftWorkflow) {
        self.service = service
        self.preferences = preferences
        self.aiDraftWorkflow = aiDraftWorkflow
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 430, height: 670)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        aiTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        view = effectView
        buildInterface()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesChanged),
            name: .appPreferencesDidChange,
            object: preferences
        )

        updatePreferencesSummary()
        reloadAIProviders()
        updateSelectionSummary()
        updateEmptyStateVisibility()
        applyFeedback("보이는 카카오톡 채팅방을 고르고 메시지를 작성한 뒤 드라이런 또는 전송을 사용하세요.", kind: .info)
        updateStatusSummary(headline: "카카오톡 상태를 확인하는 중…", detail: "팝오버를 열어 상태와 보이는 채팅방 목록을 새로고침하세요.", tint: .secondaryLabelColor)
        updateUIState()
        publishStatusAppearance()
    }

    func popoverWillShow() {
        if isBusy { return }
        reloadAIProviders()
        hasLoadedOnce = true
        refreshAll(trigger: .popover)
    }

    func refreshFromMenu() {
        guard !isBusy else { return }
        if !hasLoadedOnce {
            hasLoadedOnce = true
        }
        refreshAll(trigger: .manual)
    }

    func refreshStatusSilently() {
        guard !isBusy else { return }

        let service = self.service
        performBackgroundWork {
            try service.status(promptForTrust: false)
        } completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let status):
                self.latestStatus = status
                self.updateStatusSummary(
                    headline: self.makeStatusHeadline(status: status),
                    detail: self.makeStatusDetail(status: status),
                    tint: self.makeStatusTint(status: status)
                )
                self.requestAccessButton.isHidden = status.permission.trusted
                if !status.permission.trusted {
                    self.triggerPermissionPromptIfNeeded()
                }
                self.publishStatusAppearance()
            case .failure:
                break
            }
        }
    }

    private func triggerPermissionPromptIfNeeded() {
        guard !hasTriggeredPermissionPrompt else { return }
        hasTriggeredPermissionPrompt = true
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func buildInterface() {
        headerTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        statusHeadlineLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusHeadlineLabel.lineBreakMode = .byWordWrapping

        statusDetailLabel.font = .systemFont(ofSize: 12)
        statusDetailLabel.textColor = .secondaryLabelColor
        statusDetailLabel.lineBreakMode = .byWordWrapping
        statusDetailLabel.maximumNumberOfLines = 3

        chatCountLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        chatCountLabel.textColor = .secondaryLabelColor

        selectionLabel.font = .systemFont(ofSize: 12)
        selectionLabel.lineBreakMode = .byWordWrapping
        selectionLabel.maximumNumberOfLines = 2

        roomNameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        messageLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        aiProviderLabel.font = .systemFont(ofSize: 11)
        aiProviderLabel.lineBreakMode = .byWordWrapping
        aiProviderLabel.maximumNumberOfLines = 2

        feedbackLabel.font = .systemFont(ofSize: 12)
        feedbackLabel.lineBreakMode = .byWordWrapping
        feedbackLabel.maximumNumberOfLines = 3

        emptyStateLabel.font = .systemFont(ofSize: 12)
        emptyStateLabel.textColor = .secondaryLabelColor
        emptyStateLabel.alignment = .center
        emptyStateLabel.lineBreakMode = .byWordWrapping
        emptyStateLabel.maximumNumberOfLines = 2
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false

        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        statusIconView.setContentHuggingPriority(.required, for: .horizontal)

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.isDisplayedWhenStopped = false

        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "새로고침")
        refreshButton.bezelStyle = .texturedRounded
        refreshButton.target = self
        refreshButton.action = #selector(handleRefresh)

        requestAccessButton.bezelStyle = .rounded
        requestAccessButton.target = self
        requestAccessButton.action = #selector(handlePromptForTrust)
        requestAccessButton.isHidden = true

        aiDraftButton.bezelStyle = .rounded
        aiDraftButton.target = self
        aiDraftButton.action = #selector(handleAIDraft)

        aiAskButton.bezelStyle = .rounded
        aiAskButton.target = self
        aiAskButton.action = #selector(handleAIAsk)

        aiUseReplyButton.bezelStyle = .rounded
        aiUseReplyButton.target = self
        aiUseReplyButton.action = #selector(handleUseLastAIReply)

        aiRewriteButton.bezelStyle = .rounded
        aiRewriteButton.target = self
        aiRewriteButton.action = #selector(handleAIRewrite)

        dryRunButton.bezelStyle = .rounded
        dryRunButton.target = self
        dryRunButton.action = #selector(handleDryRun)

        sendButton.bezelStyle = .rounded
        sendButton.target = self
        sendButton.action = #selector(handleSend)

        configureChatsTableView()
        configureRoomNameField()
        configureAIConversationTextView()
        configureAIPromptField()
        configureMessageTextView()

        let statusTextStack = NSStackView(views: [statusHeadlineLabel, statusDetailLabel])
        statusTextStack.orientation = .vertical
        statusTextStack.spacing = 2
        statusTextStack.alignment = .leading

        let headerControlsStack = NSStackView(views: [requestAccessButton, refreshButton, progressIndicator])
        headerControlsStack.orientation = .horizontal
        headerControlsStack.spacing = 8
        headerControlsStack.alignment = .centerY

        let titleRow = NSStackView(views: [headerTitleLabel, NSView(), headerControlsStack])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY

        let statusRow = NSStackView(views: [statusIconView, statusTextStack])
        statusRow.orientation = .horizontal
        statusRow.alignment = .top
        statusRow.spacing = 10

        let chatsScrollView = NSScrollView()
        chatsScrollView.translatesAutoresizingMaskIntoConstraints = false
        chatsScrollView.hasVerticalScroller = true
        chatsScrollView.borderType = .bezelBorder
        chatsScrollView.drawsBackground = true
        chatsScrollView.documentView = chatsTableView
        chatsScrollView.heightAnchor.constraint(equalToConstant: 210).isActive = true

        let chatsContainer = NSView()
        chatsContainer.translatesAutoresizingMaskIntoConstraints = false
        chatsContainer.addSubview(chatsScrollView)
        chatsContainer.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            chatsScrollView.leadingAnchor.constraint(equalTo: chatsContainer.leadingAnchor),
            chatsScrollView.trailingAnchor.constraint(equalTo: chatsContainer.trailingAnchor),
            chatsScrollView.topAnchor.constraint(equalTo: chatsContainer.topAnchor),
            chatsScrollView.bottomAnchor.constraint(equalTo: chatsContainer.bottomAnchor),
            emptyStateLabel.centerXAnchor.constraint(equalTo: chatsContainer.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: chatsContainer.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: chatsContainer.leadingAnchor, constant: 16),
            emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: chatsContainer.trailingAnchor, constant: -16)
        ])

        let aiLabel = makeSectionLabel("AI 초안 보조")
        let aiButtonsRow = NSStackView(views: [aiProviderLabel, NSView(), aiAskButton, aiDraftButton, aiRewriteButton])
        aiButtonsRow.orientation = .horizontal
        aiButtonsRow.alignment = .centerY
        aiButtonsRow.spacing = 8

        let aiConversationScrollView = NSScrollView()
        aiConversationScrollView.translatesAutoresizingMaskIntoConstraints = false
        aiConversationScrollView.borderType = .bezelBorder
        aiConversationScrollView.hasVerticalScroller = true
        aiConversationScrollView.drawsBackground = true
        aiConversationScrollView.documentView = aiConversationTextView
        aiConversationScrollView.heightAnchor.constraint(equalToConstant: 100).isActive = true

        let aiConversationLabel = makeSectionLabel("대화")
        let aiConversationHeader = NSStackView(views: [aiConversationLabel, NSView(), aiUseReplyButton])
        aiConversationHeader.orientation = .horizontal
        aiConversationHeader.alignment = .centerY
        aiConversationHeader.spacing = 8

        let messageScrollView = NSScrollView()
        messageScrollView.translatesAutoresizingMaskIntoConstraints = false
        messageScrollView.borderType = .bezelBorder
        messageScrollView.hasVerticalScroller = true
        messageScrollView.drawsBackground = true
        messageScrollView.documentView = messageTextView
        messageScrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true

        let buttonsRow = NSStackView(views: [NSView(), dryRunButton, sendButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .centerY
        buttonsRow.spacing = 8

        let rootStack = NSStackView(views: [
            titleRow,
            statusRow,
            makeSeparator(),
            roomNameLabel,
            roomNameField,
            messageLabel,
            messageScrollView,
            buttonsRow,
            selectionLabel,
            chatCountLabel,
            chatsContainer,
            aiLabel,
            aiConversationHeader,
            aiConversationScrollView,
            aiPromptField,
            aiButtonsRow,
            feedbackLabel
        ])
        rootStack.orientation = .vertical
        rootStack.spacing = 12
        rootStack.alignment = .leading
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            statusIconView.widthAnchor.constraint(equalToConstant: 18),
            statusIconView.heightAnchor.constraint(equalToConstant: 18),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
            chatsContainer.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            chatsScrollView.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            roomNameField.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            aiConversationScrollView.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            aiPromptField.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            messageScrollView.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            aiButtonsRow.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            buttonsRow.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            titleRow.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            statusRow.widthAnchor.constraint(equalTo: rootStack.widthAnchor)
        ])
    }

    private func configureChatsTableView() {
        let column = NSTableColumn(identifier: .init("chat"))
        column.resizingMask = .autoresizingMask
        chatsTableView.addTableColumn(column)
        chatsTableView.headerView = nil
        chatsTableView.rowHeight = 46
        chatsTableView.intercellSpacing = NSSize(width: 0, height: 4)
        chatsTableView.allowsEmptySelection = true
        chatsTableView.allowsMultipleSelection = false
        chatsTableView.selectionHighlightStyle = .regular
        chatsTableView.usesAlternatingRowBackgroundColors = false
        chatsTableView.delegate = self
        chatsTableView.dataSource = self
    }

    private func configureRoomNameField() {
        roomNameField.font = .systemFont(ofSize: 13)
        roomNameField.placeholderString = "채팅방 이름을 입력하세요"
        roomNameField.delegate = self
        roomNameField.target = self
        roomNameField.action = #selector(handleRoomNameChanged)
    }

    private func configureMessageTextView() {
        messageTextView.font = .systemFont(ofSize: 13)
        messageTextView.textColor = .labelColor
        messageTextView.backgroundColor = .textBackgroundColor
        messageTextView.isRichText = false
        messageTextView.importsGraphics = false
        messageTextView.allowsUndo = true
        messageTextView.isVerticallyResizable = true
        messageTextView.isHorizontallyResizable = false
        messageTextView.autoresizingMask = [.width]
        messageTextView.textContainerInset = NSSize(width: 8, height: 8)
        messageTextView.textContainer?.containerSize = NSSize(width: preferredContentSize.width - 48, height: .greatestFiniteMagnitude)
        messageTextView.textContainer?.widthTracksTextView = true
        messageTextView.delegate = self
    }

    private func configureAIPromptField() {
        aiPromptField.font = .systemFont(ofSize: 12)
        aiPromptField.placeholderString = "AI에게 질문하거나, 보내고 싶은 메시지를 설명하세요"
        aiPromptField.delegate = self
        aiPromptField.target = self
        aiPromptField.action = #selector(handleAIPromptChanged)
    }

    private func configureAIConversationTextView() {
        aiConversationTextView.font = .systemFont(ofSize: 12)
        aiConversationTextView.textColor = .secondaryLabelColor
        aiConversationTextView.backgroundColor = .textBackgroundColor
        aiConversationTextView.isEditable = false
        aiConversationTextView.isSelectable = true
        aiConversationTextView.textContainerInset = NSSize(width: 8, height: 8)
        aiConversationTextView.string = "아직 AI 대화가 없습니다. 질문을 하거나 원하는 메시지를 설명해 보세요."
    }

    private func makeSectionLabel(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        chats.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard chats.indices.contains(row) else { return nil }
        let chat = chats[row]
        let cellView = (tableView.makeView(withIdentifier: ChatListCellView.identifier, owner: self) as? ChatListCellView)
            ?? ChatListCellView(frame: .zero)
        cellView.identifier = ChatListCellView.identifier
        cellView.configure(with: chat)
        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let previousChatID = selectedChatID
        let row = chatsTableView.selectedRow
        selectedChatID = chats.indices.contains(row) ? chats[row].chatID : nil
        if let selectedChat = selectedChat {
            roomNameField.stringValue = selectedChat.title
        }
        if previousChatID != selectedChatID {
            aiConversation.removeAll()
            updateAIConversationSummary()
        }
        updateSelectionSummary()
        updateUIState()
        if selectedChatID != nil {
            view.window?.makeFirstResponder(messageTextView)
        }
    }

    func textDidChange(_ notification: Notification) {
        updateUIState()
    }

    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSTextField == aiPromptField || obj.object as? NSTextField == roomNameField {
            updateUIState()
        }
    }

    @objc private func handleRefresh() {
        refreshFromMenu()
    }

    @objc private func handlePromptForTrust() {
        refreshAll(trigger: .promptForTrust)
    }

    @objc private func handleOpenSettings() {
        onOpenSettings?()
    }

    @objc private func handleRoomNameChanged() {
        if let selectedChat, roomNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) != selectedChat.title {
            selectedChatID = nil
            chatsTableView.deselectAll(nil)
            updateSelectionSummary()
        }
        updateUIState()
    }

    @objc private func handleDryRun() {
        runSend(dryRun: true)
    }

    @objc private func handleSend() {
        runSend(dryRun: false)
    }

    @objc private func handleAIDraft() {
        runAIAction(.draft)
    }

    @objc private func handleAIAsk() {
        runAIConversationAsk()
    }

    @objc private func handleAIRewrite() {
        runAIAction(.rewrite)
    }

    @objc private func handleUseLastAIReply() {
        guard let reply = aiConversation.last(where: { $0.role == "assistant" }) else {
            applyFeedback("아직 적용할 AI 답변이 없습니다.", kind: .warning)
            return
        }
        messageTextView.string = reply.content
        updateUIState()
        view.window?.makeFirstResponder(messageTextView)
        applyFeedback("마지막 AI 답변을 메시지 초안으로 옮겼습니다. 검토한 뒤 드라이런 또는 전송을 사용하세요.", kind: .success)
    }

    @objc private func handleAIPromptChanged() {
        updateUIState()
    }

    @objc private func handlePreferencesChanged() {
        updatePreferencesSummary()
        reloadAIProviders()
        updateUIState()
    }

    private func refreshAll(trigger: RefreshTrigger) {
        let service = self.service
        let promptForTrust = trigger == .promptForTrust
        let loadingMessage = promptForTrust ? "macOS 접근성 권한 요청을 여는 중…" : "카카오톡 상태와 보이는 채팅방을 새로고침하는 중…"

        isBusy = true
        progressIndicator.startAnimation(nil)
        applyFeedback(loadingMessage, kind: .info)

        performBackgroundWork {
            let status = try service.status(promptForTrust: promptForTrust)
            var chats: [ChatSummaryResult] = []
            var chatsError: Error?
            if status.permission.trusted && status.kakaoTalkRunning && status.loginState == "ready" {
                do {
                    chats = try service.chats(limit: 50).chats
                } catch {
                    chatsError = error
                }
            }
            return RefreshSnapshot(status: status, chats: chats, chatsError: chatsError)
        } completion: { [weak self] result in
            guard let self else { return }
            self.isBusy = false
            self.progressIndicator.stopAnimation(nil)

            switch result {
            case .success(let snapshot):
                self.applyRefresh(snapshot)
            case .failure(let error):
                self.latestStatus = nil
                self.chats = []
                self.selectedChatID = nil
                self.chatsTableView.reloadData()
                self.updateEmptyStateVisibility()
                self.updateSelectionSummary()
                self.updateStatusSummary(
                    headline: "자동화 상태를 확인할 수 없음",
                    detail: self.userMessage(for: error),
                    tint: .systemRed
                )
                self.applyFeedback(self.userMessage(for: error), kind: .error)
                self.publishStatusAppearance()
            }
        }
    }

    private func applyRefresh(_ snapshot: RefreshSnapshot) {
        latestStatus = snapshot.status
        chats = snapshot.chats
        restoreSelectionIfPossible()
        chatsTableView.reloadData()
        updateEmptyStateVisibility()
        updateSelectionSummary()
        updateStatusSummary(
            headline: makeStatusHeadline(status: snapshot.status),
            detail: makeStatusDetail(status: snapshot.status),
            tint: makeStatusTint(status: snapshot.status)
        )

        requestAccessButton.isHidden = snapshot.status.permission.trusted

        if !snapshot.status.permission.trusted {
            applyFeedback(
                "메뉴 막대 앱을 실행하는 프로세스에 접근성 권한이 있어야 카카오톡 자동화를 사용할 수 있습니다.",
                kind: .error
            )
        } else if !snapshot.status.kakaoTalkRunning {
            applyFeedback(
                "카카오톡이 실행 중이 아닙니다. 실행하고 로그인한 뒤 팝오버를 다시 열어 채팅방을 불러오세요.",
                kind: .warning
            )
        } else if snapshot.status.loginState != "ready" {
            applyFeedback(loginStateMessage(snapshot.status.loginState), kind: .warning)
        } else if let chatsError = snapshot.chatsError {
            applyFeedback("카카오톡에는 접근했지만 보이는 채팅방을 불러오지 못했습니다: \(userMessage(for: chatsError))", kind: .error)
        } else if snapshot.chats.isEmpty {
            applyFeedback("현재 카카오톡 목록 창에서 보이는 채팅방을 찾지 못했습니다.", kind: .warning)
        } else {
            applyFeedback("보이는 카카오톡 채팅방 \(snapshot.chats.count)개를 불러왔습니다. 드라이런은 실제 전송 없이 흐름을 안전하게 확인합니다.", kind: .success)
        }

        publishStatusAppearance()
    }

    private func restoreSelectionIfPossible() {
        guard let selectedChatID else {
            chatsTableView.deselectAll(nil)
            return
        }
        guard let row = chats.firstIndex(where: { $0.chatID == selectedChatID }) else {
            self.selectedChatID = nil
            chatsTableView.deselectAll(nil)
            return
        }
        chatsTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    private func runSend(dryRun: Bool) {
        let draft = ComposeDraftState(selectedChatID: selectedChatID, chatName: roomNameField.stringValue, message: messageTextView.string, isBusy: isBusy)
        guard draft.canSubmit else { return }

        let service = self.service
        let keepWindowOpen = preferences.keepChatWindowOpen
        let matchMode = preferences.defaultMatchMode
        let sendSpeed = preferences.defaultSendSpeed
        let message = draft.trimmedMessage
        let selectedChat = self.selectedChat
        let chatID = selectedChat?.chatID
        let chatName = draft.trimmedChatName

        isBusy = true
        progressIndicator.startAnimation(nil)
        applyFeedback(dryRun ? "KTalkAXService로 드라이런을 실행하는 중…" : "KTalkAXService로 전송하고 검증을 기다리는 중…", kind: .info)

        performBackgroundWork {
            try service.send(
                chat: chatName,
                chatID: chatID,
                message: message,
                dryRun: dryRun,
                keepWindow: keepWindowOpen,
                matchMode: matchMode,
                speed: sendSpeed
            )
        } completion: { [weak self] result in
            guard let self else { return }
            self.isBusy = false
            self.progressIndicator.stopAnimation(nil)

            switch result {
            case .success(let sendResult):
                if !dryRun {
                    self.messageTextView.string = ""
                }
                self.updateUIState()
                let fallbackText = sendResult.usedFallback.isEmpty ? "" : " 대체 수단: \(sendResult.usedFallback.joined(separator: ", "))."
                let successText = dryRun
                    ? "\(sendResult.matchedChat) 채팅방 기준으로 드라이런 준비를 마쳤습니다. 실제 메시지는 보내지 않았습니다.\(fallbackText)"
                    : "\(sendResult.matchedChat) 채팅방에 전송했고 카카오톡에서 검증까지 마쳤습니다.\(fallbackText)"
                self.applyFeedback(successText, kind: .success)
            case .failure(let error):
                self.applyFeedback(self.userMessage(for: error), kind: .error)
            }
        }
    }

    private func runAIAction(_ action: AIDraftAction) {
        guard !isBusy else { return }
        reloadAIProviders()

        guard let selectedChat else {
            applyFeedback("AI 초안 기능을 쓰기 전에 보이는 카카오톡 채팅방을 먼저 선택하세요.", kind: .warning)
            return
        }

        guard let provider = preferences.resolvedAIProvider(from: availableAIProviders) else {
            applyFeedback(noAIProviderMessage(), kind: .warning)
            return
        }

        let instructions = aiPromptField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentMessage = messageTextView.string
        let trimmedMessage = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatTitle = selectedChat.title

        switch action {
        case .draft:
            guard !instructions.isEmpty || !trimmedMessage.isEmpty else {
                applyFeedback("AI 초안을 요청하기 전에 짧은 지시문이나 초안 메모를 먼저 입력하세요.", kind: .warning)
                return
            }
        case .rewrite:
            guard !trimmedMessage.isEmpty else {
                applyFeedback("먼저 초안을 작성하거나 붙여넣은 뒤 AI로 다듬기를 사용하세요.", kind: .warning)
                return
            }
        }

        aiTask?.cancel()
        isBusy = true
        progressIndicator.startAnimation(nil)
        applyFeedback("\(action.progressMessage) 제공자: \(provider.displayName).", kind: .info)

        aiTask = Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await self.aiDraftWorkflow.compose(
                    action: action,
                    provider: provider,
                    chatTitle: chatTitle,
                    instructions: instructions,
                    currentMessage: currentMessage
                )
                guard !Task.isCancelled else { return }
                self.applyAIResult(result, action: action)
            } catch {
                guard !Task.isCancelled else { return }
                self.isBusy = false
                self.progressIndicator.stopAnimation(nil)
                self.updateUIState()
                self.applyFeedback(self.userMessage(for: error), kind: .error)
            }
        }
    }

    private func runAIConversationAsk() {
        guard !isBusy else { return }
        reloadAIProviders()

        guard let selectedChat else {
            applyFeedback("AI 대화를 시작하기 전에 보이는 카카오톡 채팅방을 먼저 선택하세요.", kind: .warning)
            return
        }

        guard let provider = preferences.resolvedAIProvider(from: availableAIProviders) else {
            applyFeedback(noAIProviderMessage(), kind: .warning)
            return
        }

        let prompt = aiPromptField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            applyFeedback("먼저 AI에게 물을 질문이나 원하는 메시지 요청을 입력하세요.", kind: .warning)
            return
        }

        let currentMessage = messageTextView.string
        let priorConversation = aiConversation
        aiTask?.cancel()
        isBusy = true
        progressIndicator.startAnimation(nil)
        applyFeedback("\(provider.displayName)로 AI에게 묻는 중…", kind: .info)

        aiTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.aiDraftWorkflow.ask(
                    provider: provider,
                    chatTitle: selectedChat.title,
                    prompt: prompt,
                    currentMessage: currentMessage,
                    conversation: priorConversation
                )
                guard !Task.isCancelled else { return }
                self.isBusy = false
                self.progressIndicator.stopAnimation(nil)
                self.aiConversation.append(AIChatTurn(role: "user", content: prompt))
                self.aiConversation.append(AIChatTurn(role: "assistant", content: result.text))
                self.aiPromptField.stringValue = ""
                self.updateAIConversationSummary()
                self.updateUIState()
                self.applyFeedback("AI가 \(result.provider.displayName) · \(result.model)으로 답변했습니다. 원하면 '마지막 답변 적용'으로 초안에 넣을 수 있습니다.", kind: .success)
            } catch {
                guard !Task.isCancelled else { return }
                self.isBusy = false
                self.progressIndicator.stopAnimation(nil)
                self.updateUIState()
                self.applyFeedback(self.userMessage(for: error), kind: .error)
            }
        }
    }

    private func applyAIResult(_ result: AIComposeResult, action: AIDraftAction) {
        isBusy = false
        progressIndicator.stopAnimation(nil)

        let composedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !composedText.isEmpty else {
            updateUIState()
            applyFeedback("AI 제공자가 빈 초안을 돌려줬습니다. 지시문을 조정한 뒤 다시 시도하세요.", kind: .error)
            return
        }

        messageTextView.string = composedText
        updateUIState()
        view.window?.makeFirstResponder(messageTextView)
        applyFeedback("\(action.successVerb): \(result.provider.displayName) · \(result.model). 메시지를 검토한 뒤 드라이런 또는 전송을 사용하세요.", kind: .success)
    }

    private func updateAIConversationSummary() {
        if aiConversation.isEmpty {
            aiConversationTextView.string = "아직 AI 대화가 없습니다. 질문을 하거나 원하는 메시지를 설명해 보세요."
            return
        }
        aiConversationTextView.string = aiConversation.map { turn in
            let prefix = turn.role == "assistant" ? "AI" : "나"
            return "\(prefix): \(turn.content)"
        }.joined(separator: "\n\n")
    }

    private var selectedChat: ChatSummaryResult? {
        guard let selectedChatID else { return nil }
        return chats.first(where: { $0.chatID == selectedChatID })
    }

    private func updateUIState() {
        let draft = ComposeDraftState(selectedChatID: selectedChatID, chatName: roomNameField.stringValue, message: messageTextView.string, isBusy: isBusy)
        let hasAIProvider = preferences.resolvedAIProvider(from: availableAIProviders) != nil
        let trimmedPrompt = aiPromptField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        dryRunButton.isEnabled = draft.canSubmit
        sendButton.isEnabled = draft.canSubmit
        aiAskButton.isEnabled = !isBusy && selectedChat != nil && hasAIProvider && !trimmedPrompt.isEmpty
        aiDraftButton.isEnabled = !isBusy && selectedChat != nil && hasAIProvider && (!trimmedPrompt.isEmpty || !draft.trimmedMessage.isEmpty)
        aiRewriteButton.isEnabled = !isBusy && selectedChat != nil && hasAIProvider && !draft.trimmedMessage.isEmpty
        aiUseReplyButton.isEnabled = !isBusy && aiConversation.contains(where: { $0.role == "assistant" })
        refreshButton.isEnabled = !isBusy
        requestAccessButton.isEnabled = !isBusy
        roomNameField.isEnabled = !isBusy
        aiPromptField.isEnabled = !isBusy
        messageTextView.isEditable = !isBusy
    }

    private func updatePreferencesSummary() {
    }

    private func reloadAIProviders() {
        availableAIProviders = aiDraftWorkflow.availableProviders
        updateAIProviderSummary()
        updatePreferencesSummary()
        updateUIState()
    }

    private func updateAIProviderSummary() {
        if let provider = preferences.resolvedAIProvider(from: availableAIProviders) {
            aiProviderLabel.stringValue = "제공자: \(provider.displayName). 전송 전에 AI에게 묻기, 초안 생성, 다듬기를 사용할 수 있습니다."
            aiProviderLabel.textColor = .secondaryLabelColor
        } else {
            aiProviderLabel.stringValue = "설정된 AI 제공자가 없습니다. 자격 정보를 추가한 뒤 설정에서 제공자를 선택하세요."
            aiProviderLabel.textColor = .systemOrange
        }
    }

    private func updateSelectionSummary() {
        if let selectedChat {
            selectionLabel.stringValue = "선택됨: \(selectedChat.title) (\(selectedChat.chatID)) — 바로 드라이런 또는 전송할 수 있습니다."
        } else {
            selectionLabel.stringValue = "채팅방 이름을 직접 입력하거나, 아래 목록에서 선택한 뒤 바로 전송할 수 있습니다."
        }
    }

    private func updateEmptyStateVisibility() {
        emptyStateLabel.isHidden = !chats.isEmpty
    }

    private func updateStatusSummary(headline: String, detail: String, tint: NSColor) {
        statusHeadlineLabel.stringValue = headline
        statusDetailLabel.stringValue = detail
        statusIconView.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
        statusIconView.contentTintColor = tint
    }

    private func makeStatusHeadline(status: StatusResult) -> String {
        let trustText = status.permission.trusted ? "접근성 권한 허용됨" : "접근성 권한 필요"
        let runningText = status.kakaoTalkRunning ? "카카오톡 실행 중" : "카카오톡 실행 안 됨"
        return "\(trustText) · \(runningText)"
    }

    private func makeStatusDetail(status: StatusResult) -> String {
        "로그인: \(humanReadableLoginState(status.loginState)) · 창 수: \(status.activeWindowCount)"
    }

    private func makeStatusTint(status: StatusResult) -> NSColor {
        if !status.permission.trusted {
            return .systemRed
        }
        if !status.kakaoTalkRunning || status.loginState != "ready" {
            return .systemOrange
        }
        return .systemGreen
    }

    private func humanReadableLoginState(_ loginState: String) -> String {
        switch loginState {
        case "ready": return "준비 완료"
        case "permission_denied": return "권한 필요"
        case "not_running": return "실행 안 됨"
        case "login_required": return "로그인 필요"
        case "app_locked": return "잠김"
        case "unknown": return "알 수 없음"
        default: return loginState.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func loginStateMessage(_ loginState: String) -> String {
        switch loginState {
        case "login_required":
            return "카카오톡이 로그아웃된 상태로 보입니다. 메뉴 막대 흐름을 쓰기 전에 직접 열어서 로그인하세요."
        case "app_locked":
            return "카카오톡이 잠긴 상태로 보입니다. 먼저 잠금을 해제한 뒤 메뉴 막대 팝오버를 새로고침하세요."
        case "permission_denied":
            return "현재 설치된 ~/Applications/katalk-ax.app 기준으로 접근성 권한이 필요합니다. 설정에서 해당 항목을 켜고, 필요하면 권한 요청 버튼을 다시 눌러 주세요."
        case "not_running":
            return "현재 카카오톡이 실행 중이 아닙니다."
        default:
            return "아직 카카오톡이 준비되지 않았습니다. 현재 로그인 상태: \(humanReadableLoginState(loginState))."
        }
    }

    private func applyFeedback(_ message: String, kind: FeedbackKind) {
        feedbackLabel.stringValue = message
        switch kind {
        case .info:
            feedbackLabel.textColor = .secondaryLabelColor
        case .success:
            feedbackLabel.textColor = .systemGreen
        case .warning:
            feedbackLabel.textColor = .systemOrange
        case .error:
            feedbackLabel.textColor = .systemRed
        }
    }

    private func publishStatusAppearance() {
        onStatusAppearanceChange?(currentStatusAppearance(), latestStatus)
    }

    private func noAIProviderMessage() -> String {
        "설정된 AI 제공자가 없습니다. ~/.katalk-ax/ai-providers.json 을 추가하거나 GEMINI_API_KEY / OPENAI_API_KEY를 설정한 뒤 설정에서 제공자를 선택하세요."
    }

    private func currentStatusAppearance() -> MenuBarStatusItemAppearance {
        MenuBarStatusAppearanceResolver.resolve(
            isBusy: isBusy,
            latestStatus: latestStatus
        )
    }

    private func userMessage(for error: Error) -> String {
        if let error = error as? KTalkAXError {
            return error.userFacingMessage
        }
        return error.localizedDescription
    }

    private func performBackgroundWork<T>(
        _ work: @escaping () throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let box = BackgroundWorkBox()
        backgroundWorkBoxes.append(box)

        box.backgroundAction = { [weak self, weak box] in
            guard let self, let box else { return }

            let result: Result<T, Error>
            do {
                result = .success(try work())
            } catch {
                result = .failure(error)
            }

            box.mainThreadAction = { [weak self, weak box] in
                completion(result)
                guard let self, let box else { return }
                self.backgroundWorkBoxes.removeAll { $0 === box }
            }

            box.performSelector(onMainThread: #selector(BackgroundWorkBox.runMainThreadAction), with: nil, waitUntilDone: false)
        }

        Thread.detachNewThreadSelector(#selector(BackgroundWorkBox.runBackgroundAction), toTarget: box, with: nil)
    }
}

private final class BackgroundWorkBox: NSObject {
    var backgroundAction: (() -> Void)?
    var mainThreadAction: (() -> Void)?

    @objc func runBackgroundAction() {
        backgroundAction?()
    }

    @objc func runMainThreadAction() {
        mainThreadAction?()
    }
}
