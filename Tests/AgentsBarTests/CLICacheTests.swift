import Commander
import Testing
@testable import AgentsBarCLI

struct CLICacheTests {
    @Test
    func `cache clear parses cookies provider flags`() throws {
        let parser = CommandParser(signature: AgentsBarCLI._cacheSignatureForTesting())
        let parsed = try parser.parse(arguments: ["--cookies", "--provider", "claude", "--json"])

        #expect(parsed.flags.contains("cookies"))
        #expect(parsed.flags.contains("jsonShortcut"))
        #expect(parsed.options["provider"] == ["claude"])
        #expect(AgentsBarCLI._decodeFormatForTesting(from: parsed) == .json)
    }

    @Test
    func `provider scope is rejected for cost clearing`() {
        #expect(AgentsBarCLI.cacheClearProviderScopeError(rawProvider: nil, clearCost: true) == nil)
        #expect(AgentsBarCLI.cacheClearProviderScopeError(rawProvider: "claude", clearCost: false) == nil)
        #expect(AgentsBarCLI.cacheClearProviderScopeError(rawProvider: "claude", clearCost: true)?
            .contains("--provider only scopes cookie caches") == true)
    }

    @Test
    func `cache help documents provider as cookie scoped`() {
        let help = AgentsBarCLI.cacheHelp(version: "0.0.0")

        #expect(help.contains("--provider with --cookies"))
        #expect(help.contains("agentsbar cache clear --cookies --provider claude"))
    }
}
