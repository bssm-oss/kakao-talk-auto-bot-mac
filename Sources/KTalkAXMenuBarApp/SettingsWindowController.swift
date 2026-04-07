import AppKit
import Foundation
import KTalkAXCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsViewController: SettingsViewController

    init(preferences: AppPreferences, aiDraftWorkflow: AIDraftWorkflow) {
        self.settingsViewController = SettingsViewController(preferences: preferences, aiDraftWorkflow: aiDraftWorkflow)

        let window = NSWindow(contentViewController: settingsViewController)
        window.title = "katalk-ax 설정"
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

    private let descriptionLabel = NSTextField(labelWithString: "이 기본 설정은 네이티브 메뉴 막대 앱에만 적용됩니다. CLI 동작은 그대로 유지됩니다.")
    private let matchModePopUp = NSPopUpButton()
    private let sendSpeedPopUp = NSPopUpButton()
    private let keepWindowCheckbox = NSButton(checkboxWithTitle: "드라이런 또는 전송 후에도 채팅창 유지", target: nil, action: nil)
    private let aiDescriptionLabel = NSTextField(labelWithString: "AI 초안 기능은 선택 사항입니다. 결과는 메시지 입력칸에만 채워지므로 드라이런이나 전송 전에 직접 검토할 수 있습니다.")
    private let aiProviderPopUp = NSPopUpButton()
    private let aiProviderStatusLabel = NSTextField(labelWithString: "")
    private let aiConfigPathLabel = NSTextField(labelWithString: "AI 설정 파일: —")
    private let statusLabel = NSTextField(labelWithString: "현재 상태: 메뉴 막대 앱에서 새로고침을 기다리는 중입니다.")
    private let cachePathLabel = NSTextField(labelWithString: "캐시 경로: —")
    private let registryPathLabel = NSTextField(labelWithString: "레지스트리 경로: —")

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
            aiProviderPopUp.addItem(withTitle: "설정된 제공자 없음")
            aiProviderPopUp.isEnabled = false
            aiProviderStatusLabel.stringValue = "~/.katalk-ax/ai-providers.json 을 추가하거나 GEMINI_API_KEY / OPENAI_API_KEY를 설정한 뒤 설정 창을 다시 여세요."
            aiProviderStatusLabel.textColor = .systemOrange
        } else {
            aiProviderPopUp.addItems(withTitles: availableAIProviders.map(\.displayName))
            aiProviderPopUp.isEnabled = true
            aiProviderStatusLabel.stringValue = "팝오버에서 AI 초안 생성과 AI 다듬기 작업에 이 제공자를 사용합니다."
            aiProviderStatusLabel.textColor = .secondaryLabelColor
        }

        aiConfigPathLabel.stringValue = "AI 설정 파일: \(aiDraftWorkflow.configurationPath)"
        syncControlsFromPreferences()
    }

    func update(status: StatusResult?) {
        guard let status else {
            statusLabel.stringValue = "현재 상태: 메뉴 막대 앱에서 새로고침을 기다리는 중입니다."
            cachePathLabel.stringValue = "캐시 경로: —"
            registryPathLabel.stringValue = "레지스트리 경로: —"
            return
        }

        let loginText: String = switch status.loginState {
        case "ready": "준비 완료"
        case "permission_denied": "권한 필요"
        case "not_running": "실행 안 됨"
        case "login_required": "로그인 필요"
        case "app_locked": "잠김"
        case "unknown": "알 수 없음"
        default: status.loginState
        }
        statusLabel.stringValue = "현재 상태: \(status.permission.trusted ? "권한 허용" : "권한 필요") · \(status.kakaoTalkRunning ? "실행 중" : "실행 안 됨") · 로그인 \(loginText)"
        cachePathLabel.stringValue = "캐시 경로: \(status.cachePath)"
        registryPathLabel.stringValue = "레지스트리 경로: \(status.registryPath)"
    }

    private func buildInterface() {
        let titleLabel = NSTextField(labelWithString: "메뉴 막대 기본 설정")
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

        let matchModeLabel = makeFieldLabel("기본 매칭 방식")
        let sendSpeedLabel = makeFieldLabel("기본 속도")
        let aiProviderLabel = makeFieldLabel("기본 AI 제공자")

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

        let runtimeLabel = NSTextField(labelWithString: "실행 정보")
        runtimeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        runtimeLabel.textColor = .secondaryLabelColor

        let aiLabel = NSTextField(labelWithString: "AI 초안 보조")
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
        matchModePopUp.addItems(withTitles: ["정확 일치", "스마트", "퍼지"])
        matchModePopUp.target = self
        matchModePopUp.action = #selector(handleMatchModeChanged)

        sendSpeedPopUp.addItems(withTitles: ["느림", "보통", "빠름"])
        sendSpeedPopUp.target = self
        sendSpeedPopUp.action = #selector(handleSendSpeedChanged)

        aiProviderPopUp.target = self
        aiProviderPopUp.action = #selector(handleAIProviderChanged)

        keepWindowCheckbox.target = self
        keepWindowCheckbox.action = #selector(handleKeepWindowChanged)
    }

    private func syncControlsFromPreferences() {
        let selectedMatchTitle = switch preferences.defaultMatchMode {
        case .exact: "정확 일치"
        case .smart: "스마트"
        case .fuzzy: "퍼지"
        }
        let selectedSpeedTitle = switch preferences.defaultSendSpeed {
        case .slow: "느림"
        case .normal: "보통"
        case .fast: "빠름"
        }
        matchModePopUp.selectItem(withTitle: selectedMatchTitle)
        sendSpeedPopUp.selectItem(withTitle: selectedSpeedTitle)
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
