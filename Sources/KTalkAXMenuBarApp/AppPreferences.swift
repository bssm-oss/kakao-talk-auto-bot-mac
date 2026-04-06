import Foundation
import KTalkAXCore

extension Notification.Name {
    static let appPreferencesDidChange = Notification.Name("KTalkAXMenuBarAppPreferencesDidChange")
}

@MainActor
final class AppPreferences {
    private enum Keys {
        static let defaultMatchMode = "menuBar.defaultMatchMode"
        static let defaultSendSpeed = "menuBar.defaultSendSpeed"
        static let keepChatWindowOpen = "menuBar.keepChatWindowOpen"
        static let defaultAIProvider = "menuBar.defaultAIProvider"
    }

    private let defaults: UserDefaults

    var defaultMatchMode: ChatMatchMode {
        didSet { persist(defaultMatchMode.rawValue, forKey: Keys.defaultMatchMode) }
    }

    var defaultSendSpeed: SendSpeed {
        didSet { persist(defaultSendSpeed.rawValue, forKey: Keys.defaultSendSpeed) }
    }

    var keepChatWindowOpen: Bool {
        didSet { persist(keepChatWindowOpen, forKey: Keys.keepChatWindowOpen) }
    }

    var defaultAIProvider: AIProviderKind? {
        didSet { persistOptionalString(defaultAIProvider?.rawValue, forKey: Keys.defaultAIProvider) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultMatchMode = ChatMatchMode(rawValue: defaults.string(forKey: Keys.defaultMatchMode) ?? "") ?? .exact
        self.defaultSendSpeed = SendSpeed(rawValue: defaults.string(forKey: Keys.defaultSendSpeed) ?? "") ?? .normal
        self.keepChatWindowOpen = defaults.object(forKey: Keys.keepChatWindowOpen) as? Bool ?? false
        self.defaultAIProvider = AIProviderKind(rawValue: defaults.string(forKey: Keys.defaultAIProvider) ?? "")
    }

    var summaryText: String {
        let closeBehavior = keepChatWindowOpen ? "keep chat open" : "close after send"
        let aiText = defaultAIProvider?.displayName ?? "AI auto"
        return "Defaults: \(defaultMatchMode.rawValue.capitalized) match · \(defaultSendSpeed.rawValue.capitalized) speed · \(closeBehavior) · \(aiText)"
    }

    func resolvedAIProvider(from availableProviders: [AIProviderKind]) -> AIProviderKind? {
        guard !availableProviders.isEmpty else { return nil }
        if let defaultAIProvider, availableProviders.contains(defaultAIProvider) {
            return defaultAIProvider
        }
        return availableProviders.first
    }

    private func persist(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .appPreferencesDidChange, object: self)
    }

    private func persistOptionalString(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        NotificationCenter.default.post(name: .appPreferencesDidChange, object: self)
    }
}
