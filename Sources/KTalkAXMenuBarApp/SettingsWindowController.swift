import AppKit
import Foundation
import KTalkAXCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsViewController: SettingsViewController

    init(preferences: AppPreferences, aiDraftWorkflow: AIDraftWorkflow) {
        self.settingsViewController = SettingsViewController(preferences: preferences, aiDraftWorkflow: aiDraftWorkflow)

        let window = NSWindow(contentViewController: settingsViewController)
        window.title = "katalk-ax Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 460, height: 430))
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func showWindowAndActivate() {
        settingsViewController.reloadAIProviders()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(status: StatusResult?) {
        settingsViewController.update(status: status)
    }
}

@MainActor
private final class SettingsViewController: NSViewController {
    private let preferences: AppPreferences
    private let aiDraftWorkflow: AIDraftWorkflow
    private var availableAIProviders: [AIProviderKind] = []

    private let descriptionLabel = NSTextField(labelWithString: "These defaults apply to the native menu bar app only. The CLI remains unchanged.")
    private let matchModePopUp = NSPopUpButton()
    private let sendSpeedPopUp = NSPopUpButton()
    private let keepWindowCheckbox = NSButton(checkboxWithTitle: "Keep chat window open after dry run or send", target: nil, action: nil)
    private let aiDescriptionLabel = NSTextField(labelWithString: "AI drafting stays optional. It only writes into the message box so you can review the result before Dry Run or Send.")
    private let aiProviderPopUp = NSPopUpButton()
    private let aiProviderStatusLabel = NSTextField(labelWithString: "")
    private let aiConfigPathLabel = NSTextField(labelWithString: "AI config: —")
    private let statusLabel = NSTextField(labelWithString: "Current status: waiting for a refresh from the menu bar app.")
    private let cachePathLabel = NSTextField(labelWithString: "Cache path: —")
    private let registryPathLabel = NSTextField(labelWithString: "Registry path: —")

    init(preferences: AppPreferences, aiDraftWorkflow: AIDraftWorkflow) {
        self.preferences = preferences
        self.aiDraftWorkflow = aiDraftWorkflow
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let effectView = NSVisualEffectView()
        effectView.material = .sidebar
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        view = effectView
        buildInterface()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureControls()
        reloadAIProviders()
        syncControlsFromPreferences()
    }

    func reloadAIProviders() {
        availableAIProviders = aiDraftWorkflow.availableProviders
        aiProviderPopUp.removeAllItems()

        if availableAIProviders.isEmpty {
            aiProviderPopUp.addItem(withTitle: "No provider configured")
            aiProviderPopUp.isEnabled = false
            aiProviderStatusLabel.stringValue = "Add ~/.katalk-ax/ai-providers.json or set GEMINI_API_KEY / OPENAI_API_KEY, then reopen Settings."
            aiProviderStatusLabel.textColor = .systemOrange
        } else {
            aiProviderPopUp.addItems(withTitles: availableAIProviders.map(\.displayName))
            aiProviderPopUp.isEnabled = true
            aiProviderStatusLabel.stringValue = "The popover will use this provider for AI Draft and Rewrite with AI."
            aiProviderStatusLabel.textColor = .secondaryLabelColor
        }

        aiConfigPathLabel.stringValue = "AI config: \(aiDraftWorkflow.configurationPath)"
        syncControlsFromPreferences()
    }

    func update(status: StatusResult?) {
        guard let status else {
            statusLabel.stringValue = "Current status: waiting for a refresh from the menu bar app."
            cachePathLabel.stringValue = "Cache path: —"
            registryPathLabel.stringValue = "Registry path: —"
            return
        }

        statusLabel.stringValue = "Current status: \(status.permission.trusted ? "trusted" : "permission required") · \(status.kakaoTalkRunning ? "running" : "not running") · login \(status.loginState)"
        cachePathLabel.stringValue = "Cache path: \(status.cachePath)"
        registryPathLabel.stringValue = "Registry path: \(status.registryPath)"
    }

    private func buildInterface() {
        let titleLabel = NSTextField(labelWithString: "Menu Bar Defaults")
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        descriptionLabel.font = .systemFont(ofSize: 12)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 2

        aiDescriptionLabel.font = .systemFont(ofSize: 12)
        aiDescriptionLabel.textColor = .secondaryLabelColor
        aiDescriptionLabel.lineBreakMode = .byWordWrapping
        aiDescriptionLabel.maximumNumberOfLines = 3

        aiProviderStatusLabel.font = .systemFont(ofSize: 11)
        aiProviderStatusLabel.lineBreakMode = .byWordWrapping
        aiProviderStatusLabel.maximumNumberOfLines = 3

        aiConfigPathLabel.font = .systemFont(ofSize: 11)
        aiConfigPathLabel.textColor = .secondaryLabelColor
        aiConfigPathLabel.lineBreakMode = .byTruncatingMiddle

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        cachePathLabel.font = .systemFont(ofSize: 11)
        cachePathLabel.textColor = .secondaryLabelColor
        cachePathLabel.lineBreakMode = .byTruncatingMiddle

        registryPathLabel.font = .systemFont(ofSize: 11)
        registryPathLabel.textColor = .secondaryLabelColor
        registryPathLabel.lineBreakMode = .byTruncatingMiddle

        let matchModeLabel = makeFieldLabel("Default matching")
        let sendSpeedLabel = makeFieldLabel("Default speed")
        let aiProviderLabel = makeFieldLabel("Default AI provider")

        let grid = NSGridView(views: [
            [matchModeLabel, matchModePopUp],
            [sendSpeedLabel, sendSpeedPopUp],
            [aiProviderLabel, aiProviderPopUp]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.xPlacement = .leading
        grid.yPlacement = .center

        let runtimeLabel = NSTextField(labelWithString: "Runtime")
        runtimeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        runtimeLabel.textColor = .secondaryLabelColor

        let aiLabel = NSTextField(labelWithString: "AI Draft Assist")
        aiLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        aiLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            titleLabel,
            descriptionLabel,
            makeSeparator(),
            grid,
            keepWindowCheckbox,
            makeSeparator(),
            aiLabel,
            aiDescriptionLabel,
            aiProviderStatusLabel,
            aiConfigPathLabel,
            makeSeparator(),
            runtimeLabel,
            statusLabel,
            cachePathLabel,
            registryPathLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
            grid.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func configureControls() {
        matchModePopUp.addItems(withTitles: [ChatMatchMode.exact, .smart, .fuzzy].map { $0.rawValue.capitalized })
        matchModePopUp.target = self
        matchModePopUp.action = #selector(handleMatchModeChanged)

        sendSpeedPopUp.addItems(withTitles: [SendSpeed.slow, .normal, .fast].map { $0.rawValue.capitalized })
        sendSpeedPopUp.target = self
        sendSpeedPopUp.action = #selector(handleSendSpeedChanged)

        aiProviderPopUp.target = self
        aiProviderPopUp.action = #selector(handleAIProviderChanged)

        keepWindowCheckbox.target = self
        keepWindowCheckbox.action = #selector(handleKeepWindowChanged)
    }

    private func syncControlsFromPreferences() {
        matchModePopUp.selectItem(withTitle: preferences.defaultMatchMode.rawValue.capitalized)
        sendSpeedPopUp.selectItem(withTitle: preferences.defaultSendSpeed.rawValue.capitalized)
        keepWindowCheckbox.state = preferences.keepChatWindowOpen ? .on : .off

        guard let provider = preferences.resolvedAIProvider(from: availableAIProviders),
              let index = availableAIProviders.firstIndex(of: provider) else {
            aiProviderPopUp.selectItem(at: 0)
            return
        }
        aiProviderPopUp.selectItem(at: index)
    }

    private func makeFieldLabel(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        return label
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    @objc private func handleMatchModeChanged() {
        let selectedMode = [ChatMatchMode.exact, .smart, .fuzzy][matchModePopUp.indexOfSelectedItem]
        preferences.defaultMatchMode = selectedMode
    }

    @objc private func handleSendSpeedChanged() {
        let selectedSpeed = [SendSpeed.slow, .normal, .fast][sendSpeedPopUp.indexOfSelectedItem]
        preferences.defaultSendSpeed = selectedSpeed
    }

    @objc private func handleKeepWindowChanged() {
        preferences.keepChatWindowOpen = keepWindowCheckbox.state == .on
    }

    @objc private func handleAIProviderChanged() {
        guard availableAIProviders.indices.contains(aiProviderPopUp.indexOfSelectedItem) else {
            preferences.defaultAIProvider = nil
            return
        }
        preferences.defaultAIProvider = availableAIProviders[aiProviderPopUp.indexOfSelectedItem]
    }
}
