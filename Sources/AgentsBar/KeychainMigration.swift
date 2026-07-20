import AgentsBarCore
import Foundation
import Security

/// Migrates keychain items to use kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
/// to prevent permission prompts on every rebuild during development.
enum KeychainMigration {
    private static let log = AgentsBarLog.logger(LogCategories.keychainMigration)
    private static let migrationKey = "KeychainMigrationV1Completed"

    struct MigrationItem: Hashable {
        let service: String
        let account: String?

        var label: String {
            let accountLabel = self.account ?? "<any>"
            return "\(self.service):\(accountLabel)"
        }
    }

    // Legacy CodexBar keychain service kept for one-shot migration from pre-rename installs.
    private static let legacyKeychainService = "com.steipete.CodexBar"

    static let itemsToMigrate: [MigrationItem] = [
        MigrationItem(service: self.legacyKeychainService, account: "codex-cookie"),
        MigrationItem(service: self.legacyKeychainService, account: "claude-cookie"),
        MigrationItem(service: self.legacyKeychainService, account: "cursor-cookie"),
        MigrationItem(service: self.legacyKeychainService, account: "factory-cookie"),
        MigrationItem(service: self.legacyKeychainService, account: "minimax-cookie"),
        MigrationItem(service: self.legacyKeychainService, account: "minimax-api-token"),
        MigrationItem(service: self.legacyKeychainService, account: "augment-cookie"),
        MigrationItem(service: self.legacyKeychainService, account: "copilot-api-token"),
        MigrationItem(service: self.legacyKeychainService, account: "zai-api-token"),
        MigrationItem(service: self.legacyKeychainService, account: "synthetic-api-key"),
    ]

    /// Run migration once per installation
    static func migrateIfNeeded() {
        guard !KeychainAccessGate.isDisabled else {
            self.log.info("Keychain access disabled; skipping migration")
            return
        }

        if !UserDefaults.standard.bool(forKey: self.migrationKey) {
            self.log.info("Starting keychain migration to reduce permission prompts")

            var migratedCount = 0
            var errorCount = 0

            for item in self.itemsToMigrate {
                do {
                    if try self.migrateItem(item) {
                        migratedCount += 1
                    }
                } catch {
                    errorCount += 1
                    self.log.error("Failed to migrate \(item.label): \(String(describing: error))")
                }
            }

            self.log.info("Keychain migration complete: \(migratedCount) migrated, \(errorCount) errors")
            UserDefaults.standard.set(true, forKey: self.migrationKey)

            if migratedCount > 0 {
                self.log.info("✅ Future rebuilds will not prompt for keychain access")
            }
        } else {
            self.log.debug("Keychain migration already completed, skipping")
        }
    }

    /// Migrate a single keychain item to the new accessibility level
    /// Returns true if item was migrated, false if item didn't exist
    private static func migrateItem(_ item: MigrationItem) throws -> Bool {
        // First, try to read the existing item
        var result: CFTypeRef?
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: item.service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
        ]
        if let account = item.account {
            query[kSecAttrAccount as String] = account
        }

        let status = KeychainSecurity.copyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            // Item doesn't exist, nothing to migrate
            return false
        }

        guard status == errSecSuccess else {
            throw KeychainMigrationError.readFailed(status)
        }

        guard let rawItem = result as? [String: Any],
              let data = rawItem[kSecValueData as String] as? Data,
              let accessible = rawItem[kSecAttrAccessible as String] as? String
        else {
            throw KeychainMigrationError.invalidItemFormat
        }

        // Check if already using the correct accessibility
        if accessible == (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String) {
            self.log.debug("\(item.label) already using correct accessibility")
            return false
        }

        // Delete the old item
        var deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: item.service,
        ]
        if let account = item.account {
            deleteQuery[kSecAttrAccount as String] = account
        }

        let deleteStatus = KeychainSecurity.delete(deleteQuery as CFDictionary)
        guard deleteStatus == errSecSuccess else {
            throw KeychainMigrationError.deleteFailed(deleteStatus)
        }

        // Add it back with the new accessibility
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: item.service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        if let account = item.account {
            addQuery[kSecAttrAccount as String] = account
        }

        let addStatus = KeychainSecurity.add(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainMigrationError.addFailed(addStatus)
        }

        self.log.info("Migrated \(item.label) to new accessibility level")
        return true
    }

    /// Reset migration flag (for testing)
    static func resetMigrationFlag() {
        UserDefaults.standard.removeObject(forKey: self.migrationKey)
    }
}

enum KeychainMigrationError: Error {
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case addFailed(OSStatus)
    case invalidItemFormat
}
