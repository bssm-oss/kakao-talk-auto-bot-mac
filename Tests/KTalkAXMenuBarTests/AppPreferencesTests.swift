import Foundation
import Testing
@testable import KTalkAXMenuBarApp

struct AppPreferencesTests {
    @MainActor
    @Test func preferencesPersistAcrossInstances() {
        let suiteName = "KTalkAXMenuBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = AppPreferences(defaults: defaults)
        preferences.defaultMatchMode = .fuzzy
        preferences.defaultSendSpeed = .slow
        preferences.keepChatWindowOpen = true
        preferences.defaultAIProvider = .gemini

        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.defaultMatchMode == .fuzzy)
        #expect(reloaded.defaultSendSpeed == .slow)
        #expect(reloaded.keepChatWindowOpen)
        #expect(reloaded.defaultAIProvider == .gemini)
    }

    @MainActor
    @Test func resolvedAIProviderFallsBackToFirstConfiguredProvider() {
        let suiteName = "KTalkAXMenuBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = AppPreferences(defaults: defaults)
        preferences.defaultAIProvider = .gemini

        #expect(preferences.resolvedAIProvider(from: [.openAICompatible]) == .openAICompatible)
    }
}
