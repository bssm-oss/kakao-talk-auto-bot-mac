import AppKit
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
    private var backgroundWorkBoxes: [BackgroundWorkBox] = []
    private var aiTask: Task<Void, Never>?
    private var isBusy = false {
        didSet {
            updateUIState()
            publishStatusAppearance()
        }
    }

    private let headerTitleLabel = NSTextField(labelWithString: "KakaoTalk Automation")
    private let statusIconView = NSImageView()
    private let statusHeadlineLabel = NSTextField(labelWithString: "Checking KakaoTalk status…")
    private let statusDetailLabel = NSTextField(labelWithString: "The menu bar app uses the shared KTalkAXService directly.")
    private let refreshButton = NSButton(title: "", target: nil, action: nil)
    private let requestAccessButton = NSButton(title: "Prompt Access", target: nil, action: nil)
    private let progressIndicator = NSProgressIndicator()
    private let chatCountLabel = NSTextField(labelWithString: "Visible chats")
    private let emptyStateLabel = NSTextField(labelWithString: "No visible chats loaded yet.")
    private let selectionLabel = NSTextField(labelWithString: "Select a visible KakaoTalk chat to enable Dry Run and Send.")
    private let preferencesLabel = NSTextField(labelWithString: "")
    private let aiProviderLabel = NSTextField(labelWithString: "")
    private let feedbackLabel = NSTextField(labelWithString: "")
    private let chatsTableView = NSTableView()
    private let aiConversationTextView = NSTextView(frame: .zero)
    private let aiPromptField = NSTextField(string: "")
    private let messageTextView = NSTextView(frame: .zero)
    private let aiAskButton = NSButton(title: "Ask AI", target: nil, action: nil)
    private let aiUseReplyButton = NSButton(title: "Use Last Reply", target: nil, action: nil)
    private let aiDraftButton = NSButton(title: "AI Draft", target: nil, action: nil)
    private let aiRewriteButton = NSButton(title: "Rewrite with AI", target: nil, action: nil)
    private let dryRunButton = NSButton(title: "Dry Run", target: nil, action: nil)
    private let sendButton = NSButton(title: "Send", target: nil, action: nil)
    private let settingsButton = NSButton(title: "Settings…", target: nil, action: nil)

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
        applyFeedback("Choose a visible KakaoTalk chat, write a message, then use Dry Run or Send.", kind: .info)
        updateStatusSummary(headline: "Checking KakaoTalk status…", detail: "Open the popover to refresh status and visible chats.", tint: .secondaryLabelColor)
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

        preferencesLabel.font = .systemFont(ofSize: 11)
        preferencesLabel.textColor = .secondaryLabelColor
        preferencesLabel.lineBreakMode = .byWordWrapping
        preferencesLabel.maximumNumberOfLines = 2

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

        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        refreshButton.bezelStyle = .texturedRounded
        refreshButton.target = self
        refreshButton.action = #selector(handleRefresh)

        requestAccessButton.bezelStyle = .rounded
        requestAccessButton.target = self
        requestAccessButton.action = #selector(handlePromptForTrust)
        requestAccessButton.isHidden = true

        settingsButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(handleOpenSettings)

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

        let aiLabel = makeSectionLabel("AI Draft Assist")
        let messageLabel = makeSectionLabel("Message")
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

        let aiConversationLabel = makeSectionLabel("Conversation")
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

        let buttonsRow = NSStackView(views: [settingsButton, NSView(), dryRunButton, sendButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .centerY
        buttonsRow.spacing = 8

        let rootStack = NSStackView(views: [
            titleRow,
            statusRow,
            makeSeparator(),
            chatCountLabel,
            chatsContainer,
            selectionLabel,
            aiLabel,
            aiConversationHeader,
            aiConversationScrollView,
            aiPromptField,
            aiButtonsRow,
            messageLabel,
            messageScrollView,
            preferencesLabel,
            buttonsRow,
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
        aiPromptField.placeholderString = "Ask AI anything about the message, or describe what you want to send"
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
        aiConversationTextView.string = "No AI conversation yet. Ask a question or describe the message you want."
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
        if obj.object as? NSTextField == aiPromptField {
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
            applyFeedback("There is no AI reply to apply yet.", kind: .warning)
            return
        }
        messageTextView.string = reply.content
        updateUIState()
        view.window?.makeFirstResponder(messageTextView)
        applyFeedback("Moved the last AI reply into the message draft. Review it, then use Dry Run or Send.", kind: .success)
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
        let loadingMessage = promptForTrust ? "Requesting the macOS Accessibility prompt…" : "Refreshing KakaoTalk status and visible chats…"

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
                    headline: "Automation status unavailable",
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
                "Accessibility permission is required for the menu bar app host before any KakaoTalk automation can run.",
                kind: .error
            )
        } else if !snapshot.status.kakaoTalkRunning {
            applyFeedback(
                "KakaoTalk is not running. Launch it, sign in, and reopen the popover to load chats.",
                kind: .warning
            )
        } else if snapshot.status.loginState != "ready" {
            applyFeedback(loginStateMessage(snapshot.status.loginState), kind: .warning)
        } else if let chatsError = snapshot.chatsError {
            applyFeedback("KakaoTalk is reachable, but visible chats could not be loaded: \(userMessage(for: chatsError))", kind: .error)
        } else if snapshot.chats.isEmpty {
            applyFeedback("No visible chats were found in the current KakaoTalk list window.", kind: .warning)
        } else {
            applyFeedback("Loaded \(snapshot.chats.count) visible chats. Dry Run keeps the workflow safe without pressing send.", kind: .success)
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
        let draft = ComposeDraftState(selectedChatID: selectedChatID, message: messageTextView.string, isBusy: isBusy)
        guard draft.canSubmit, let selectedChat = selectedChat else { return }

        let service = self.service
        let keepWindowOpen = preferences.keepChatWindowOpen
        let matchMode = preferences.defaultMatchMode
        let sendSpeed = preferences.defaultSendSpeed
        let message = draft.trimmedMessage

        isBusy = true
        progressIndicator.startAnimation(nil)
        applyFeedback(dryRun ? "Running a dry run through KTalkAXService…" : "Sending through KTalkAXService and waiting for verification…", kind: .info)

        performBackgroundWork {
            try service.send(
                chatID: selectedChat.chatID,
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
                let fallbackText = sendResult.usedFallback.isEmpty ? "" : " Fallbacks: \(sendResult.usedFallback.joined(separator: ", "))."
                let successText = dryRun
                    ? "Dry run prepared \(sendResult.matchedChat). No message was sent.\(fallbackText)"
                    : "Sent to \(sendResult.matchedChat) and verified in KakaoTalk.\(fallbackText)"
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
            applyFeedback("Select a visible KakaoTalk chat before using AI draft assist.", kind: .warning)
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
                applyFeedback("Add a short AI prompt or some draft notes before asking for an AI draft.", kind: .warning)
                return
            }
        case .rewrite:
            guard !trimmedMessage.isEmpty else {
                applyFeedback("Write or paste a draft first, then use Rewrite with AI.", kind: .warning)
                return
            }
        }

        aiTask?.cancel()
        isBusy = true
        progressIndicator.startAnimation(nil)
        applyFeedback("\(action.progressMessage) Provider: \(provider.displayName).", kind: .info)

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
            applyFeedback("Select a visible KakaoTalk chat before starting an AI conversation.", kind: .warning)
            return
        }

        guard let provider = preferences.resolvedAIProvider(from: availableAIProviders) else {
            applyFeedback(noAIProviderMessage(), kind: .warning)
            return
        }

        let prompt = aiPromptField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            applyFeedback("Enter an AI question or message request first.", kind: .warning)
            return
        }

        let currentMessage = messageTextView.string
        let priorConversation = aiConversation
        aiTask?.cancel()
        isBusy = true
        progressIndicator.startAnimation(nil)
        applyFeedback("Asking AI with \(provider.displayName)…", kind: .info)

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
                self.applyFeedback("AI replied with \(result.provider.displayName) · \(result.model). Use Last Reply to move it into the draft if you want.", kind: .success)
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
            applyFeedback("The AI provider returned an empty draft. Adjust the prompt and try again.", kind: .error)
            return
        }

        messageTextView.string = composedText
        updateUIState()
        view.window?.makeFirstResponder(messageTextView)
        applyFeedback("\(action.successVerb) with \(result.provider.displayName) · \(result.model). Review the message, then use Dry Run or Send.", kind: .success)
    }

    private func updateAIConversationSummary() {
        if aiConversation.isEmpty {
            aiConversationTextView.string = "No AI conversation yet. Ask a question or describe the message you want."
            return
        }
        aiConversationTextView.string = aiConversation.map { turn in
            let prefix = turn.role == "assistant" ? "AI" : "You"
            return "\(prefix): \(turn.content)"
        }.joined(separator: "\n\n")
    }

    private var selectedChat: ChatSummaryResult? {
        guard let selectedChatID else { return nil }
        return chats.first(where: { $0.chatID == selectedChatID })
    }

    private func updateUIState() {
        let draft = ComposeDraftState(selectedChatID: selectedChatID, message: messageTextView.string, isBusy: isBusy)
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
        settingsButton.isEnabled = !isBusy
        aiPromptField.isEnabled = !isBusy
        messageTextView.isEditable = !isBusy
    }

    private func updatePreferencesSummary() {
        preferencesLabel.stringValue = preferences.summaryText
    }

    private func reloadAIProviders() {
        availableAIProviders = aiDraftWorkflow.availableProviders
        updateAIProviderSummary()
        updatePreferencesSummary()
        updateUIState()
    }

    private func updateAIProviderSummary() {
        if let provider = preferences.resolvedAIProvider(from: availableAIProviders) {
            aiProviderLabel.stringValue = "Provider: \(provider.displayName). Ask AI, draft, or rewrite before sending."
            aiProviderLabel.textColor = .secondaryLabelColor
        } else {
            aiProviderLabel.stringValue = "No AI provider configured. Add credentials, then choose a provider in Settings."
            aiProviderLabel.textColor = .systemOrange
        }
    }

    private func updateSelectionSummary() {
        if let selectedChat {
            selectionLabel.stringValue = "Selected: \(selectedChat.title) (\(selectedChat.chatID))"
        } else {
            selectionLabel.stringValue = "Select a visible KakaoTalk chat to enable Dry Run and Send."
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
        let trustText = status.permission.trusted ? "Accessibility granted" : "Accessibility required"
        let runningText = status.kakaoTalkRunning ? "KakaoTalk running" : "KakaoTalk not running"
        return "\(trustText) · \(runningText)"
    }

    private func makeStatusDetail(status: StatusResult) -> String {
        "Login: \(humanReadableLoginState(status.loginState)) · Windows: \(status.activeWindowCount)"
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
        case "ready": return "Ready"
        case "permission_denied": return "Permission required"
        case "not_running": return "Not running"
        case "login_required": return "Login required"
        case "app_locked": return "Locked"
        case "unknown": return "Unknown"
        default: return loginState.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func loginStateMessage(_ loginState: String) -> String {
        switch loginState {
        case "login_required":
            return "KakaoTalk looks logged out. Open KakaoTalk manually and sign in before using the menu bar workflow."
        case "app_locked":
            return "KakaoTalk appears locked. Unlock it first, then refresh the menu bar popover."
        case "permission_denied":
            return "Accessibility access is required before the menu bar app can inspect or automate KakaoTalk."
        case "not_running":
            return "KakaoTalk is not currently running."
        default:
            return "KakaoTalk is not ready yet. Current login state: \(humanReadableLoginState(loginState))."
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
        "No AI provider is configured. Add ~/.katalk-ax/ai-providers.json or set GEMINI_API_KEY / OPENAI_API_KEY, then choose a provider in Settings."
    }

    private func currentStatusAppearance() -> MenuBarStatusItemAppearance {
        if isBusy {
            return MenuBarStatusItemAppearance(
                symbolName: "arrow.triangle.2.circlepath.circle.fill",
                tintColor: .controlAccentColor,
                tooltip: "katalk-ax: refreshing KakaoTalk status"
            )
        }

        guard let latestStatus else {
            return MenuBarStatusItemAppearance(
                symbolName: "ellipsis.message",
                tintColor: .labelColor,
                tooltip: "katalk-ax: status unavailable"
            )
        }

        if !latestStatus.permission.trusted {
            return MenuBarStatusItemAppearance(
                symbolName: "exclamationmark.triangle.fill",
                tintColor: .systemRed,
                tooltip: "katalk-ax: Accessibility access required"
            )
        }

        if !latestStatus.kakaoTalkRunning {
            return MenuBarStatusItemAppearance(
                symbolName: "bolt.slash.circle.fill",
                tintColor: .systemOrange,
                tooltip: "katalk-ax: KakaoTalk is not running"
            )
        }

        if latestStatus.loginState != "ready" {
            return MenuBarStatusItemAppearance(
                symbolName: "exclamationmark.bubble.fill",
                tintColor: .systemOrange,
                tooltip: "katalk-ax: KakaoTalk needs attention"
            )
        }

        return MenuBarStatusItemAppearance(
            symbolName: "bubble.left.and.bubble.right.fill",
            tintColor: .systemGreen,
            tooltip: "katalk-ax: KakaoTalk ready"
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
