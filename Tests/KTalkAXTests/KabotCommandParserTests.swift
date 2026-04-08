import Testing
@testable import KTalkAXCore

struct KabotCommandParserTests {
    @Test func parsesRoomAndMessage() throws {
        let parser = KabotCommandParser()
        let command = try parser.parse(arguments: ["kabot", "--room", "허동운", "--message", "안녕"])
        let required = try #require(command)
        #expect(required.room == "허동운")
        #expect(required.message == "안녕")
        #expect(required.dryRun == false)
    }

    @Test func supportsRomeAliasAndEmDashNormalization() throws {
        let parser = KabotCommandParser()
        let command = try parser.parse(arguments: ["kabot", "—rome", "허동운", "—message", "안녕", "--dry-run"])
        let required = try #require(command)
        #expect(required.room == "허동운")
        #expect(required.message == "안녕")
        #expect(required.dryRun)
    }

    @Test func returnsNilForHelp() throws {
        let parser = KabotCommandParser()
        #expect(try parser.parse(arguments: ["kabot", "--help"]) == nil)
    }
}
