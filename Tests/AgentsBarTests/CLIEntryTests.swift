import AgentsBarCore
import Commander
import Foundation
import XCTest
@testable import AgentsBarCLI

final class CLIEntryTests: XCTestCase {
    func test_effectiveArgvDefaultsToUsage() {
        XCTAssertEqual(AgentsBarCLI.effectiveArgv([]), ["usage"])
        XCTAssertEqual(AgentsBarCLI.effectiveArgv(["--json"]), ["usage", "--json"])
        XCTAssertEqual(AgentsBarCLI.effectiveArgv(["usage", "--json"]), ["usage", "--json"])
    }

    func test_decodesFormatFromOptionsAndFlags() {
        let jsonOption = ParsedValues(positional: [], options: ["format": ["json"]], flags: [])
        XCTAssertEqual(AgentsBarCLI._decodeFormatForTesting(from: jsonOption), .json)

        let jsonFlag = ParsedValues(positional: [], options: [:], flags: ["json"])
        XCTAssertEqual(AgentsBarCLI._decodeFormatForTesting(from: jsonFlag), .json)

        let textDefault = ParsedValues(positional: [], options: [:], flags: [])
        XCTAssertEqual(AgentsBarCLI._decodeFormatForTesting(from: textDefault), .text)
    }

    func test_providerSelectionPrefersOverride() {
        let selection = AgentsBarCLI.providerSelection(rawOverride: "codex", enabled: [.claude, .gemini])
        XCTAssertEqual(selection.asList, [.codex])
    }

    func test_normalizeVersionExtractsNumeric() {
        XCTAssertEqual(AgentsBarCLI.normalizeVersion(raw: "codex 1.2.3 (build 4)"), "1.2.3")
        XCTAssertEqual(AgentsBarCLI.normalizeVersion(raw: "  v2.0  "), "2.0")
    }

    func test_makeHeaderIncludesVersionWhenAvailable() {
        let header = AgentsBarCLI.makeHeader(provider: .codex, version: "1.2.3", source: "cli")
        XCTAssertTrue(header.contains("Codex"))
        XCTAssertTrue(header.contains("1.2.3"))
        XCTAssertTrue(header.contains("cli"))
    }

    func test_cliVersionFallsBackToContainingAppBundle() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentsbar-cli-version-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let appURL = root.appendingPathComponent("AgentsBar.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let helpersURL = contentsURL.appendingPathComponent("Helpers", isDirectory: true)
        try FileManager.default.createDirectory(at: helpersURL, withIntermediateDirectories: true)

        let infoURL = contentsURL.appendingPathComponent("Info.plist")
        let plist: [String: Any] = ["CFBundleShortVersionString": "9.8.7"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: infoURL)

        let helperURL = helpersURL.appendingPathComponent("AgentsBarCLI")
        try Data().write(to: helperURL)

        XCTAssertEqual(AgentsBarCLI.containingAppVersion(for: helperURL), "9.8.7")
    }

    func test_cliVersionFollowsSymlinkedHelper() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentsbar-cli-version-symlink-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let appURL = root.appendingPathComponent("AgentsBar.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let helpersURL = contentsURL.appendingPathComponent("Helpers", isDirectory: true)
        let binURL = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: helpersURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)

        let infoURL = contentsURL.appendingPathComponent("Info.plist")
        let plist: [String: Any] = ["CFBundleShortVersionString": "2.4.6"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: infoURL)

        let helperURL = helpersURL.appendingPathComponent("AgentsBarCLI")
        try Data().write(to: helperURL)

        let symlinkURL = binURL.appendingPathComponent("agentsbar")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: helperURL)

        XCTAssertEqual(AgentsBarCLI.currentVersion(bundleVersion: nil, executablePath: symlinkURL.path), "2.4.6")
    }

    func test_cliVersionFallsBackToAdjacentVersionFile() throws {
        try self.expectAdjacentVersionFile(raw: "v3.2.1\n", expected: "3.2.1")
        try self.expectAdjacentVersionFile(raw: "3.2.2\n", expected: "3.2.2")
        try self.expectAdjacentVersionFile(raw: "version-3.2.3\n", expected: "version-3.2.3")
    }

    func test_cliVersionPrefersAdjacentVersionOverStandaloneBundleName() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentsbar-cli-version-bundle-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let binURL = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)

        let helperURL = binURL.appendingPathComponent("AgentsBarCLI")
        try Data().write(to: helperURL)
        try "4.5.6\n".write(
            to: binURL.appendingPathComponent("VERSION"),
            atomically: false,
            encoding: .utf8)

        XCTAssertEqual(
            AgentsBarCLI.currentVersion(bundleVersion: "AgentsBar", executablePath: helperURL.path),
            "4.5.6")
    }

    private func expectAdjacentVersionFile(raw: String, expected: String) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentsbar-cli-version-file-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let binURL = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)

        let helperURL = binURL.appendingPathComponent("AgentsBarCLI")
        try Data().write(to: helperURL)
        try raw.write(
            to: binURL.appendingPathComponent("VERSION"),
            atomically: false,
            encoding: .utf8)

        XCTAssertEqual(AgentsBarCLI.currentVersion(bundleVersion: nil, executablePath: helperURL.path), expected)
    }

    func test_renderOpenAIWebDashboardTextIncludesSummary() {
        let event = CreditEvent(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            service: "codex",
            creditsUsed: 10)
        let snapshot = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            codeReviewRemainingPercent: 45,
            codeReviewLimit: RateWindow(
                usedPercent: 55,
                windowMinutes: nil,
                resetsAt: Date().addingTimeInterval(3600),
                resetDescription: nil),
            creditEvents: [event],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            updatedAt: Date())

        let text = AgentsBarCLI.renderOpenAIWebDashboardText(snapshot)

        XCTAssertTrue(text.contains("Web session: user@example.com"))
        XCTAssertTrue(text.contains("Code review: 45% remaining (Resets in "))
        XCTAssertTrue(text.contains("Web history: 1 events"))
    }

    func test_mapsErrorsToExitCodes() {
        XCTAssertEqual(AgentsBarCLI.mapError(CodexStatusProbeError.codexNotInstalled), ExitCode(2))
        XCTAssertEqual(AgentsBarCLI.mapError(CodexStatusProbeError.timedOut), ExitCode(4))
        XCTAssertEqual(AgentsBarCLI.mapError(ClaudeWebFetchStrategyError.timedOut(seconds: 1)), ExitCode(4))
        XCTAssertEqual(AgentsBarCLI.mapError(UsageError.noRateLimitsFound), ExitCode(3))
    }

    func test_antigravityPlanDebugKeepsOneShotHelperAliveUntilDebugFetch() {
        XCTAssertTrue(AgentsBarCLI.holdsAntigravityCLISessionForPlanDebug(
            provider: .antigravity,
            planDebugEnabled: true,
            jsonOnly: false,
            persistsCLISessions: false))
        XCTAssertFalse(AgentsBarCLI.holdsAntigravityCLISessionForPlanDebug(
            provider: .codex,
            planDebugEnabled: true,
            jsonOnly: false,
            persistsCLISessions: false))
        XCTAssertFalse(AgentsBarCLI.holdsAntigravityCLISessionForPlanDebug(
            provider: .antigravity,
            planDebugEnabled: true,
            jsonOnly: true,
            persistsCLISessions: false))
        XCTAssertFalse(AgentsBarCLI.holdsAntigravityCLISessionForPlanDebug(
            provider: .antigravity,
            planDebugEnabled: true,
            jsonOnly: false,
            persistsCLISessions: true))
    }

    func test_missingCodexBinaryErrorPayloadUsesInstallGuidance() {
        let payload = AgentsBarCLI.makeErrorPayload(CodexStatusProbeError.codexNotInstalled, kind: .provider)

        XCTAssertEqual(payload.code, ExitCode.binaryNotFound.rawValue)
        XCTAssertTrue(payload.message.contains("Codex CLI missing"))
        XCTAssertFalse(payload.message.contains("Codex not running"))
    }

    func test_providerSelectionFallsBackToBothForPrimaryPair() {
        let selection = AgentsBarCLI.providerSelection(rawOverride: nil, enabled: [.codex, .claude])
        switch selection {
        case .both:
            break
        default:
            XCTFail("Expected both selection")
        }
    }

    func test_providerSelectionFallsBackToCustomWhenNonPrimary() {
        let selection = AgentsBarCLI.providerSelection(rawOverride: nil, enabled: [.codex, .gemini])
        switch selection {
        case let .custom(providers):
            XCTAssertEqual(providers, [.codex, .gemini])
        default:
            XCTFail("Expected custom selection")
        }
    }

    func test_providerSelectionHonorsEmptyEnabledSet() {
        let selection = AgentsBarCLI.providerSelection(rawOverride: nil, enabled: [])
        switch selection {
        case let .custom(providers):
            XCTAssertEqual(providers, [])
        default:
            XCTFail("Expected empty custom selection")
        }
    }

    func test_decodesSourceAndTimeoutOptions() throws {
        let signature = AgentsBarCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--web-timeout", "45", "--source", "oauth"])
        XCTAssertEqual(try AgentsBarCLI._decodeWebTimeoutForTesting(from: parsed), 45)
        XCTAssertEqual(AgentsBarCLI._decodeSourceModeForTesting(from: parsed), .oauth)

        let parsedWeb = try parser.parse(arguments: ["--web"])
        XCTAssertEqual(AgentsBarCLI._decodeSourceModeForTesting(from: parsedWeb), .web)
    }

    func test_rejectsUnsafeWebTimeoutOptions() throws {
        for value in ["-1", "nan", "inf", "1e300"] {
            let parsed = ParsedValues(positional: [], options: ["webTimeout": [value]], flags: [])
            XCTAssertThrowsError(try AgentsBarCLI._decodeWebTimeoutForTesting(from: parsed))
        }
    }

    func test_shouldUseColorRespectsFormatAndFlags() {
        XCTAssertFalse(AgentsBarCLI.shouldUseColor(noColor: true, format: .text))
        XCTAssertFalse(AgentsBarCLI.shouldUseColor(noColor: false, format: .json))
    }

    func test_kiloUsageTextNotesShowFallbackOnlyForAutoResolvedToCLI() {
        XCTAssertEqual(AgentsBarCLI.usageTextNotes(
            provider: .kilo,
            sourceMode: .auto,
            resolvedSourceLabel: "cli"), ["Using CLI fallback"])
        XCTAssertTrue(AgentsBarCLI.usageTextNotes(
            provider: .kilo,
            sourceMode: .api,
            resolvedSourceLabel: "cli").isEmpty)
        XCTAssertTrue(AgentsBarCLI.usageTextNotes(
            provider: .codex,
            sourceMode: .auto,
            resolvedSourceLabel: "cli").isEmpty)
    }

    func test_kiloAutoFallbackSummaryIncludesOrderedAttemptDetails() {
        let attempts = [
            ProviderFetchAttempt(
                strategyID: "kilo.api",
                kind: .apiToken,
                wasAvailable: true,
                errorDescription: "Kilo authentication failed (401/403)."),
            ProviderFetchAttempt(
                strategyID: "kilo.cli",
                kind: .cli,
                wasAvailable: true,
                errorDescription: "Kilo CLI session not found."),
        ]

        let summary = AgentsBarCLI.kiloAutoFallbackSummary(
            provider: .kilo,
            sourceMode: .auto,
            attempts: attempts)
        let expected = [
            "Kilo auto fallback attempts: api: Kilo authentication failed (401/403).",
            " -> cli: Kilo CLI session not found.",
        ].joined()

        XCTAssertEqual(summary, expected)
    }

    func test_kiloAutoFallbackSummaryIsNilOutsideKiloAutoFailures() {
        let attempts = [
            ProviderFetchAttempt(
                strategyID: "kilo.api",
                kind: .apiToken,
                wasAvailable: true,
                errorDescription: "example"),
        ]

        XCTAssertNil(AgentsBarCLI.kiloAutoFallbackSummary(
            provider: .kilo,
            sourceMode: .api,
            attempts: attempts))
        XCTAssertNil(AgentsBarCLI.kiloAutoFallbackSummary(
            provider: .codex,
            sourceMode: .auto,
            attempts: attempts))
    }

    func test_sourceModeRequiresWebSupportIsProviderAware() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mimo-cli-source-mode-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let validMiMoCache = directory.appendingPathComponent("valid.json")
        let invalidMiMoCache = directory.appendingPathComponent("invalid.json")
        let payload: [String: Any] = [
            "sessions_scanned": 1,
            "windows": [
                "today": [:],
                "week": [:],
                "all_time": [:],
            ],
        ]
        try JSONSerialization.data(withJSONObject: payload).write(to: validMiMoCache)
        try Data("{}".utf8).write(to: invalidMiMoCache)

        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(.web, provider: .kilo))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(.auto, provider: .codex))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(.auto, provider: .claude))
        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(.web, provider: .claude))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(.auto, provider: .kilo))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(.auto, provider: .grok))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(.web, provider: .grok))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(.auto, provider: .amp))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(.api, provider: .kilo))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .opencodego,
            settings: ProviderSettingsSnapshot.make(
                opencodego: .init(
                    cookieSource: .manual,
                    manualCookieHeader: "auth=manual",
                    workspaceID: nil))))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .web,
            provider: .opencodego,
            settings: ProviderSettingsSnapshot.make(
                opencodego: .init(
                    cookieSource: .manual,
                    manualCookieHeader: "auth=manual",
                    workspaceID: nil))))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .opencodego,
            settings: ProviderSettingsSnapshot.make(
                opencodego: .init(
                    cookieSource: .auto,
                    manualCookieHeader: nil,
                    workspaceID: nil))))
        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(
            .web,
            provider: .opencodego,
            settings: ProviderSettingsSnapshot.make(
                opencodego: .init(
                    cookieSource: .auto,
                    manualCookieHeader: nil,
                    workspaceID: nil))))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .commandcode,
            settings: ProviderSettingsSnapshot.make(
                commandcode: .init(
                    cookieSource: .manual,
                    manualCookieHeader: "session=manual"))))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .web,
            provider: .commandcode,
            settings: ProviderSettingsSnapshot.make(
                commandcode: .init(
                    cookieSource: .manual,
                    manualCookieHeader: "session=manual"))))
        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .commandcode,
            settings: ProviderSettingsSnapshot.make(
                commandcode: .init(
                    cookieSource: .auto,
                    manualCookieHeader: nil))))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .sakana,
            environment: ["SAKANA_COOKIE": "session=manual"]))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .web,
            provider: .sakana,
            environment: ["SAKANA_COOKIE": "session=manual"]))
        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .sakana,
            environment: [:]))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .web,
            provider: .qoder,
            settings: ProviderSettingsSnapshot.make(
                qoder: .init(
                    cookieSource: .manual,
                    manualCookieHeader: "sid=manual"))))
        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(
            .web,
            provider: .qoder,
            settings: ProviderSettingsSnapshot.make(
                qoder: .init(
                    cookieSource: .auto,
                    manualCookieHeader: nil))))
        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .opencode,
            settings: ProviderSettingsSnapshot.make(
                opencode: .init(
                    cookieSource: .manual,
                    manualCookieHeader: "auth=manual",
                    workspaceID: nil))))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .ollama,
            environment: ["OLLAMA_API_KEY": "ollama-test"]))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .codex,
            environment: ["OLLAMA_API_KEY": "ollama-test"]))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .ollama,
            settings: ProviderSettingsSnapshot.make(
                ollama: .init(cookieSource: .off, manualCookieHeader: nil))))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .kimi,
            environment: ["KIMI_CODE_API_KEY": "kimi-test"]))
        try self.assertKimiCodeCredentialSourceMode(in: directory)
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .mimo,
            environment: ["MIMO_LOCAL_USAGE_PATH": validMiMoCache.path]))
        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(
            .web,
            provider: .mimo,
            environment: ["MIMO_LOCAL_USAGE_PATH": validMiMoCache.path]))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .mimo,
            environment: ["MIMO_LOCAL_USAGE_PATH": invalidMiMoCache.path]))
        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .mimo,
            environment: ["MIMO_LOCAL_USAGE_PATH": directory.appendingPathComponent("missing.json").path]))
    }

    private func assertKimiCodeCredentialSourceMode(in directory: URL) throws {
        let home = directory.appendingPathComponent("kimi-code", isDirectory: true)
        let credentials = home.appendingPathComponent("credentials", isDirectory: true)
        try FileManager.default.createDirectory(at: credentials, withIntermediateDirectories: true)
        let payload: [String: Any] = [
            "access_token": "expired",
            "refresh_token": "refresh",
            "expires_at": Date().addingTimeInterval(-60).timeIntervalSince1970,
        ]
        try JSONSerialization.data(withJSONObject: payload)
            .write(to: credentials.appendingPathComponent("kimi-code.json"))

        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .kimi,
            environment: ["KIMI_CODE_HOME": home.path]))
    }

    func test_sourceModeRequiresWebSupportAllowsFactoryAPIKeyOnLinuxGate() {
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .factory,
            environment: ["FACTORY_API_KEY": "fk-test"]))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .cli,
            provider: .factory,
            environment: ["FACTORY_API_KEY": "fk-test"]))
        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .factory,
            environment: [:]))
        XCTAssertTrue(AgentsBarCLI.sourceModeRequiresWebSupport(
            .web,
            provider: .factory,
            environment: ["FACTORY_API_KEY": "fk-test"]))
        XCTAssertFalse(AgentsBarCLI.sourceModeRequiresWebSupport(
            .api,
            provider: .factory,
            environment: [:]))
    }
}
