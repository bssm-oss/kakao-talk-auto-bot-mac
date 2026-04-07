import AppKit
import Testing
@testable import KTalkAXMenuBarApp

struct MenuBarStatusIconTests {
    @Test func resolverPrefersBusyState() {
        let appearance = MenuBarStatusAppearanceResolver.resolve(
            isBusy: true,
            permissionTrusted: true,
            kakaoTalkRunning: true,
            loginState: "ready"
        )

        #expect(appearance.glyph == .busy)
        #expect(appearance.tint == .accent)
        #expect(appearance.tooltip == "katalk-ax: KakaoTalk 상태를 새로고침하는 중")
    }

    @Test func resolverHandlesUnavailableStatus() {
        let appearance = MenuBarStatusAppearanceResolver.resolve(
            isBusy: false,
            permissionTrusted: nil,
            kakaoTalkRunning: nil,
            loginState: nil
        )

        #expect(appearance.glyph == .idle)
        #expect(appearance.tint == .neutral)
        #expect(appearance.tooltip == "katalk-ax: 상태를 확인할 수 없음")
    }

    @Test func resolverHandlesPermissionAndReadinessStates() {
        let permissionAppearance = MenuBarStatusAppearanceResolver.resolve(
            isBusy: false,
            permissionTrusted: false,
            kakaoTalkRunning: true,
            loginState: "ready"
        )
        #expect(permissionAppearance.glyph == .permissionRequired)
        #expect(permissionAppearance.tint == .error)

        let unavailableAppearance = MenuBarStatusAppearanceResolver.resolve(
            isBusy: false,
            permissionTrusted: true,
            kakaoTalkRunning: false,
            loginState: "ready"
        )
        #expect(unavailableAppearance.glyph == .unavailable)
        #expect(unavailableAppearance.tint == .warning)

        let attentionAppearance = MenuBarStatusAppearanceResolver.resolve(
            isBusy: false,
            permissionTrusted: true,
            kakaoTalkRunning: true,
            loginState: "app_locked"
        )
        #expect(attentionAppearance.glyph == .attention)
        #expect(attentionAppearance.tint == .warning)

        let readyAppearance = MenuBarStatusAppearanceResolver.resolve(
            isBusy: false,
            permissionTrusted: true,
            kakaoTalkRunning: true,
            loginState: "ready"
        )
        #expect(readyAppearance.glyph == .ready)
        #expect(readyAppearance.tint == .success)
    }

    @MainActor
    @Test func iconFactoryReturnsVisibleImageForEveryGlyph() {
        for glyph in MenuBarStatusGlyph.allCases {
            let appearance = MenuBarStatusItemAppearance(glyph: glyph, tint: .accent, tooltip: "테스트")
            let image = MenuBarStatusItemIconFactory.image(for: appearance)
            #expect(image.isTemplate == false)
            #expect(image.size == NSSize(width: 18, height: 18))
        }
    }
}
