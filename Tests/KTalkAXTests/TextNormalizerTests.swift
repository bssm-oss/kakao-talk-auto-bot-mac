import Testing
@testable import KTalkAXCore

struct TextNormalizerTests {
    @Test func normalizeCollapsesWhitespaceAndNewlines() {
        #expect(TextNormalizer.normalize("  Hello\n   World  ") == "hello world")
    }

    @Test func normalizeRemovesSeparatorsWhenRequested() {
        #expect(TextNormalizer.normalize("개발팀 (공지)", stripSeparators: true) == "개발팀 공지")
    }

    @Test func likelyHumanReadableRejectsClockOnly() {
        #expect(TextNormalizer.likelyHumanReadable("09:42") == false)
        #expect(TextNormalizer.likelyHumanReadable("홍길동") == true)
    }
}
