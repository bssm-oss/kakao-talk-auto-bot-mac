import AppKit
import Foundation

public struct StatusResult: Codable {
    public let ok: Bool
    public let command: String
    public let permission: PermissionState
    public let kakaoTalkRunning: Bool
    public let activeWindowCount: Int
    public let loginState: String
    public let cachePath: String
    public let registryPath: String
    public let textDescription: String
}

struct InspectResult: Codable {
    let ok: Bool
    let command: String
    let windowIndex: Int?
    let nodeCount: Int
    let rowsSummarized: Int
    let nodes: [AXNodeInspection]
    let rowSummary: [RowSummary]
    let textDescription: String
}

public struct ChatSummaryResult: Codable {
    public let chatID: String
    public let title: String
    public let sourceWindow: String
    public let matchableTexts: [String]
    public let unreadEstimate: Int?
    public let metaEstimate: String?
}

public struct ChatsResult: Codable {
    public let ok: Bool
    public let command: String
    public let count: Int
    public let chats: [ChatSummaryResult]
    public let textDescription: String
}

public struct SendTimings: Codable {
    public let launch: Int
    public let search: Int
    public let open: Int
    public let compose: Int
    public let send: Int
    public let verify: Int
}

public struct SendResult: Codable {
    public let ok: Bool
    public let command: String
    public let requestedChat: String
    public let matchedChat: String
    public let matchMode: ChatMatchMode
    public let matchScore: Int
    public let messageLength: Int
    public let dryRun: Bool
    public let sent: Bool
    public let verified: Bool
    public let usedFallback: [String]
    public let timingsMS: SendTimings
    public let textDescription: String

    public enum CodingKeys: String, CodingKey {
        case ok, command
        case requestedChat = "requested_chat"
        case matchedChat = "matched_chat"
        case matchMode = "match_mode"
        case matchScore = "match_score"
        case messageLength = "message_length"
        case dryRun = "dry_run"
        case sent, verified
        case usedFallback = "used_fallback"
        case timingsMS = "timings_ms"
        case textDescription
    }
}

final class KakaoTalkSender {
    private let logger: Logger
    private let cache: KakaoTalkCache
    private let registry: KakaoTalkRegistry
    private let locator: KakaoTalkLocator
    private let launcher: KakaoTalkLauncher
    private let windows: KakaoTalkWindows
    private let searchUI: KakaoTalkSearchUI
    private let composer: KakaoTalkComposer
    private let recovery: KakaoTalkRecovery
    private let matcher: KakaoTalkChatMatcher

    init(
        logger: Logger,
        cache: KakaoTalkCache,
        registry: KakaoTalkRegistry,
        locator: KakaoTalkLocator,
        launcher: KakaoTalkLauncher,
        windows: KakaoTalkWindows,
        searchUI: KakaoTalkSearchUI,
        composer: KakaoTalkComposer,
        recovery: KakaoTalkRecovery,
        matcher: KakaoTalkChatMatcher
    ) {
        self.logger = logger
        self.cache = cache
        self.registry = registry
        self.locator = locator
        self.launcher = launcher
        self.windows = windows
        self.searchUI = searchUI
        self.composer = composer
        self.recovery = recovery
        self.matcher = matcher
    }

    func status(promptForTrust: Bool) throws -> StatusResult {
        let permission = launcher.permissionState(prompt: promptForTrust)
        let running = locator.locateRunningApp()
        let appElement = running.map { AXElement.appElement(pid: $0.runningApplication.processIdentifier) }
        let windowCount: Int
        if let appElement {
            let windowsCount = (try? appElement.windows().count) ?? 0
            let focusedCount = ((try? appElement.focusedWindow()) ?? nil) == nil ? 0 : 1
            windowCount = max(windowsCount, focusedCount)
        } else {
            windowCount = 0
        }
        let loginState: String
        if !permission.trusted {
            loginState = "permission_denied"
        } else if running == nil {
            loginState = "not_running"
        } else {
            do {
                if let appElement {
                    _ = try launcher.prepare(promptForTrust: false)
                    let descriptors = try windows.descriptors(appElement: appElement)
                    loginState = descriptors.isEmpty ? "unknown" : "ready"
                } else {
                    loginState = "unknown"
                }
            } catch let error as KTalkAXError {
                loginState = error.errorCode.lowercased()
            }
        }

        return StatusResult(
            ok: permission.trusted,
            command: "status",
            permission: permission,
            kakaoTalkRunning: running != nil,
            activeWindowCount: windowCount,
            loginState: loginState,
            cachePath: cache.cacheURL.path,
            registryPath: registry.registryURL.path,
            textDescription: "접근성권한=\(permission.trusted) 실행중=\(running != nil) 창수=\(windowCount) 로그인상태=\(loginState) 캐시=\(cache.cacheURL.path) 레지스트리=\(registry.registryURL.path)"
        )
    }

    func inspect(options: InspectCommand) throws -> InspectResult {
        let prepared = try launcher.prepare(promptForTrust: false)
        let descriptors = try windows.descriptors(appElement: prepared.appElement)
        let descriptor: WindowDescriptor
        if let windowIndex = options.windowIndex {
            guard let found = descriptors.first(where: { $0.index == windowIndex }) else {
                throw KTalkAXError.invalidArguments("창 인덱스 \(windowIndex)가 존재하지 않습니다.")
            }
            descriptor = found
        } else {
            descriptor = try windows.primaryListWindow(appElement: prepared.appElement)
        }
        let dump = try AXInspector.dump(window: descriptor.element, options: options)
        return InspectResult(
            ok: true,
            command: "inspect",
            windowIndex: descriptor.index,
            nodeCount: dump.0.count,
            rowsSummarized: dump.1.count,
            nodes: dump.0,
            rowSummary: dump.1,
            textDescription: AXInspector.renderText(nodes: dump.0, rows: dump.1)
        )
    }

    func chats(options: ChatsCommand) throws -> ChatsResult {
        if options.refreshCache { try cache.reset() }
        let prepared = try launcher.prepare(promptForTrust: false)
        let listWindow = try windows.primaryListWindow(appElement: prepared.appElement)
        let (resultContainer, storedList) = try searchUI.findResultsContainer(in: listWindow.element, cache: cache, noCache: options.noCache)
        if !options.noCache {
            try cache.updateResultList(storedList)
        }
        let rows = try searchUI.collectRows(in: resultContainer, sourceWindow: listWindow.title, registry: registry)
        let output = try rows.prefix(options.limit).map { row -> ChatSummaryResult in
            let entry = try registry.upsert(title: row.title, matchableTexts: row.matchableTexts, preferredChatID: row.chatID)
            return ChatSummaryResult(chatID: entry.chatID, title: row.title, sourceWindow: row.sourceWindow, matchableTexts: row.matchableTexts, unreadEstimate: row.unreadEstimate, metaEstimate: row.metaEstimate)
        }
        let text = output.map { "\($0.chatID) | \($0.title) | 창=\($0.sourceWindow) | 후보문자열=\($0.matchableTexts.joined(separator: ", "))" }.joined(separator: "\n")
        return ChatsResult(ok: true, command: "chats", count: output.count, chats: output, textDescription: text)
    }

    func send(options: SendCommand) throws -> SendResult {
        if options.refreshCache { try cache.reset() }
        let registryEntry = registry.find(byChatID: options.chatID)
        if options.chatID != nil && registryEntry == nil {
            throw KTalkAXError.chatNotFound("chat id '\(options.chatID!)'에 해당하는 채팅방 레지스트리가 없습니다. 먼저 chats 명령으로 목록을 갱신하세요.")
        }
        let searchQuery: String = registryEntry?.title ?? options.chat ?? ""
        let requestedChat: String = options.chat ?? registryEntry?.title ?? ""
        let t0 = Date()
        let prepared = try launcher.prepare(promptForTrust: false)
        let launchMs = Int(Date().timeIntervalSince(t0) * 1000)
        let existingOpenChatWindow = try? windows.chatWindow(appElement: prepared.appElement, expectedTitle: requestedChat.isEmpty ? searchQuery : requestedChat)
        let listWindow = try windows.primaryListWindow(appElement: prepared.appElement)
        let searchStarted = Date()
        var storedSearch: StoredAXPath?
        let (resultContainer, storedList) = try searchUI.findResultsContainer(in: listWindow.element, cache: cache, noCache: options.noCache)
        if let (searchField, resolvedPath) = try? searchUI.findSearchField(in: listWindow.element, cache: cache, noCache: options.noCache) {
            storedSearch = resolvedPath
            try searchUI.clearAndTypeSearch(searchQuery, field: searchField)
            Timeout.sleep(for: options.speed, base: 0.3)
        } else {
            logger.trace("Search field not found; falling back to matching against the currently visible chat rows.")
        }
        let rows = try searchUI.collectRows(in: resultContainer, sourceWindow: listWindow.title, registry: registry)
        let selected = try matcher.match(query: searchQuery, rows: rows, mode: options.matchMode, preferredChatID: options.chatID, registry: registry)
        let searchMs = Int(Date().timeIntervalSince(searchStarted) * 1000)

        guard let matchedRow = rows.first(where: { $0.chatID == selected.chatID }) else {
            throw KTalkAXError.chatNotFound("선택한 채팅 행이 사라져서 채팅방을 열 수 없습니다.")
        }

        if !options.noCache {
            try cache.updateSearchField(storedSearch)
            try cache.updateResultList(storedList)
        }

        let openStarted = Date()
        let chatWindow: WindowDescriptor
        if let existingOpenChatWindow,
           options.chatID != nil || (!requestedChat.isEmpty && TextNormalizer.normalize(existingOpenChatWindow.title) == TextNormalizer.normalize(requestedChat)) {
            logger.trace("Using already-open chat window for requested target \(requestedChat.isEmpty ? searchQuery : requestedChat)")
            chatWindow = existingOpenChatWindow
        } else {
            let resolveCurrentRow: () throws -> ChatRowCandidate = { [self] in
                let refreshedRows = try self.searchUI.collectRows(in: resultContainer, sourceWindow: listWindow.title, registry: self.registry)
                if let exact = refreshedRows.first(where: { $0.chatID == matchedRow.chatID }) {
                    return exact
                }
                if let titled = refreshedRows.first(where: { $0.title == matchedRow.title }) {
                    return titled
                }
                logger.trace("Matched row could not be re-resolved; falling back to the original row element.")
                return matchedRow
            }
            let attemptOpen: () throws -> Void = { [self] in
                try self.launcher.activate(prepared.app)
                Thread.sleep(forTimeInterval: 0.35)
                if options.chatID == nil || storedSearch == nil {
                    let currentListWindow = try self.windows.primaryListWindow(appElement: prepared.appElement)
                    try self.searchUI.openVisibleRow(named: selected.title, in: currentListWindow.element)
                } else {
                    try self.searchUI.openRow(try resolveCurrentRow().rowElement)
                }
                Timeout.sleep(for: options.speed, base: 0.45)
            }

            do {
                try attemptOpen()
            } catch {
                try recovery.performRecoverySteps(launcher: launcher, currentApp: prepared.app, cache: cache, refreshCache: options.refreshCache, deepRecovery: options.deepRecovery)
                try attemptOpen()
            }

            do {
                chatWindow = try Timeout.poll(label: "opened chat window", timeout: 8.0, interval: 0.4) {
                    try windows.chatWindow(appElement: prepared.appElement, expectedTitle: selected.title)
                }
            } catch {
                logger.trace("First chat-window verification failed; retrying row open once more.")
                try recovery.performRecoverySteps(launcher: launcher, currentApp: prepared.app, cache: cache, refreshCache: true, deepRecovery: options.deepRecovery)
                try launcher.activate(prepared.app)
                let currentListWindow = try windows.primaryListWindow(appElement: prepared.appElement)
                try searchUI.openVisibleRow(named: selected.title, in: currentListWindow.element)
                Timeout.sleep(for: options.speed, base: 0.45)
                chatWindow = try Timeout.poll(label: "opened chat window", timeout: 8.0, interval: 0.4) {
                    try windows.chatWindow(appElement: prepared.appElement, expectedTitle: selected.title)
                }
            }
        }
        let openMs = Int(Date().timeIntervalSince(openStarted) * 1000)

        let shouldCloseWindow = !options.keepWindow
        let composeStarted = Date()
        let (composeField, composePath) = try composer.findComposeField(in: chatWindow.element, cache: cache, noCache: options.noCache)
        let (sendButton, sendPath) = try composer.findSendButton(near: composeField, in: chatWindow.element, cache: cache, noCache: options.noCache)
        if !options.noCache {
            try cache.updateComposeField(composePath)
            try cache.updateSendButton(sendPath)
        }

        if options.confirm {
            FileHandle.standardOutput.write(Data(("보낼 채팅방: \(selected.title)\n매칭 방식: \(selected.matchType) (점수 \(selected.score))\n메시지 미리보기: \(String(options.message.prefix(200)))\n계속할까요? [y/N] ").utf8))
            let response = readLine(strippingNewline: true)?.lowercased() ?? "n"
            guard response == "y" else {
                throw KTalkAXError.sendFailed("사용자 확인 단계에서 전송을 취소했습니다.")
            }
        }

        let composeFallbacks = try composer.composeMessage(options.message, in: composeField, speed: options.speed, dryRun: options.dryRun)
        let composeMs = Int(Date().timeIntervalSince(composeStarted) * 1000)

        if options.dryRun {
            if shouldCloseWindow {
                try? windows.close(window: chatWindow.element)
            }
            return SendResult(
                ok: true,
                command: "send",
                requestedChat: requestedChat,
                matchedChat: selected.title,
                matchMode: options.matchMode,
                matchScore: selected.score,
                messageLength: options.message.count,
                dryRun: true,
                sent: false,
                verified: true,
                usedFallback: composeFallbacks,
                timingsMS: SendTimings(launch: launchMs, search: searchMs, open: openMs, compose: composeMs, send: 0, verify: 0),
                textDescription: "드라이런 준비 완료: 채팅방='\(selected.title)' 매칭=\(selected.matchType) 점수=\(selected.score) 입력대체=\(composeFallbacks.joined(separator: ","))"
            )
        }

        let sendStarted = Date()
        var usedFallbacks = composeFallbacks
        usedFallbacks.append(contentsOf: try composer.sendMessage(button: sendButton, speed: options.speed))
        let sendMs = Int(Date().timeIntervalSince(sendStarted) * 1000)

        let verifyStarted = Date()
        let verified = try verifySend(message: options.message, composeField: composeField, chatWindow: chatWindow.element)
        let verifyMs = Int(Date().timeIntervalSince(verifyStarted) * 1000)

        guard verified else {
            throw KTalkAXError.verificationFailed("입력창 또는 대화 행을 기준으로 메시지 전송을 검증하지 못했습니다.")
        }

        _ = try registry.upsert(title: selected.title, matchableTexts: matchedRow.matchableTexts, preferredChatID: selected.chatID)
        if shouldCloseWindow {
            try? windows.close(window: chatWindow.element)
        }
        return SendResult(
            ok: true,
            command: "send",
            requestedChat: requestedChat,
            matchedChat: selected.title,
            matchMode: options.matchMode,
            matchScore: selected.score,
            messageLength: options.message.count,
            dryRun: false,
            sent: true,
            verified: true,
            usedFallback: usedFallbacks,
            timingsMS: SendTimings(launch: launchMs, search: searchMs, open: openMs, compose: composeMs, send: sendMs, verify: verifyMs),
            textDescription: "전송 완료: 채팅방='\(selected.title)' 매칭=\(selected.matchType) 점수=\(selected.score) 검증=true 대체수단=\(usedFallbacks.joined(separator: ","))"
        )
    }

    private func verifySend(message: String, composeField: AXElement, chatWindow: AXElement) throws -> Bool {
        let composeValue = try composeField.valueAsString() ?? ""
        if composeValue.isEmpty {
            return true
        }
        let transcript = try searchUI.transcriptRows(in: chatWindow)
        if transcript.suffix(5).contains(where: { row in
            row.bodyCandidates.contains(where: { TextNormalizer.normalize($0) == TextNormalizer.normalize(message) })
        }) {
            return true
        }
        let normalizedCompose = TextNormalizer.normalize(composeValue)
        let normalizedMessage = TextNormalizer.normalize(message)
        return normalizedCompose != normalizedMessage && composeValue.count < max(1, message.count / 2)
    }
}
