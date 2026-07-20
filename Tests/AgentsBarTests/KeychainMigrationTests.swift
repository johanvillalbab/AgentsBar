import Testing
@testable import AgentsBar

struct KeychainMigrationTests {
    @Test
    func `migration list covers known keychain items`() {
        let items = Set(KeychainMigration.itemsToMigrate.map(\.label))
        let expected: Set = [
            "com.steipete.AgentsBar:codex-cookie",
            "com.steipete.AgentsBar:claude-cookie",
            "com.steipete.AgentsBar:cursor-cookie",
            "com.steipete.AgentsBar:factory-cookie",
            "com.steipete.AgentsBar:minimax-cookie",
            "com.steipete.AgentsBar:minimax-api-token",
            "com.steipete.AgentsBar:augment-cookie",
            "com.steipete.AgentsBar:copilot-api-token",
            "com.steipete.AgentsBar:zai-api-token",
            "com.steipete.AgentsBar:synthetic-api-key",
        ]

        let missing = expected.subtracting(items)
        #expect(missing.isEmpty, "Missing migration entries: \(missing.sorted())")
    }
}
