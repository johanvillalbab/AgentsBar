import AgentsBarCore
import Testing
@testable import AgentsBar

struct KeychainPromptCoordinatorTests {
    @Test
    func `detects raw SwiftPM debug executable`() {
        #expect(KeychainPromptCoordinator.isUnbundledAgentsBarExecutable(
            "/Users/me/AgentsBar/.build/arm64-apple-macosx/debug/AgentsBar"))
        #expect(KeychainPromptCoordinator.isUnbundledAgentsBarExecutable(
            "/Users/me/AgentsBar/.build/debug/AgentsBar"))
    }

    @Test
    func `detects raw SwiftPM release executable`() {
        #expect(KeychainPromptCoordinator.isUnbundledAgentsBarExecutable(
            "/Users/me/AgentsBar/.build/arm64-apple-macosx/release/AgentsBar"))
    }

    @Test
    func `detects custom SwiftPM scratch path`() {
        #expect(KeychainPromptCoordinator.isUnbundledAgentsBarExecutable(
            "/tmp/agentsbar-build/arm64-apple-macosx/debug/AgentsBar"))
    }

    @Test
    func `keeps packaged app keychain behavior`() {
        #expect(!KeychainPromptCoordinator.isUnbundledAgentsBarExecutable(
            "/Applications/AgentsBar.app/Contents/MacOS/AgentsBar"))
        #expect(!KeychainPromptCoordinator.isUnbundledAgentsBarExecutable(
            "/Users/me/AgentsBar/.build/package/AgentsBar.app/Contents/MacOS/AgentsBar"))
    }

    @Test
    func `ignores unrelated executable paths`() {
        #expect(!KeychainPromptCoordinator.isUnbundledAgentsBarExecutable(
            "/Users/me/AgentsBar/.build/debug/AgentsBarCLI"))
        #expect(!KeychainPromptCoordinator.isUnbundledAgentsBarExecutable(""))
        #expect(!KeychainPromptCoordinator.isUnbundledAgentsBarExecutable("AgentsBar"))
    }

    @Test
    func `browser cookie alert explains password handling and opt out`() {
        let model = KeychainPromptCoordinator.browserCookieAlertModel(label: "Chrome Safe Storage")

        #expect(model.title == "Keychain Access Required")
        #expect(model.message.contains("Chrome Safe Storage"))
        #expect(model.message.contains("macOS—not AgentsBar—handles any Mac login password entry"))
        #expect(model.message.contains("Settings → Advanced"))
        #expect(model.primaryButtonTitle == "OK")
        #expect(model.learnMoreButtonTitle == "Learn More…")
        #expect(model.documentationURL.hasSuffix("/docs/keychain-prompts.md"))
    }

    @Test
    func `provider alert preserves the requested keychain purpose`() {
        let context = KeychainPromptContext(
            kind: .claudeOAuth,
            service: "Claude Code-credentials",
            account: nil)

        let model = KeychainPromptCoordinator.alertModel(for: context)

        #expect(model.message.contains("Claude Code OAuth token"))
        #expect(model.message.contains("fetch your Claude usage"))
        #expect(model.learnMoreButtonTitle == "Learn More…")
    }
}
