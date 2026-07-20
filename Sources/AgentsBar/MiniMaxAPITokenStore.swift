import AgentsBarCore
import Foundation
import Security

protocol MiniMaxAPITokenStoring: Sendable {
    func loadToken() throws -> String?
    func storeToken(_ token: String?) throws
}

enum MiniMaxAPITokenStoreError: LocalizedError {
    case keychainStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case let .keychainStatus(status):
            "Keychain error: \(status)"
        case .invalidData:
            "Keychain returned invalid data."
        }
    }
}

struct KeychainMiniMaxAPITokenStore: MiniMaxAPITokenStoring {
    private static let log = AgentsBarLog.logger(LogCategories.minimaxAPITokenStore)

    private let service = "com.steipete.AgentsBar"
    private let legacyService = "com.steipete.CodexBar"
    private let account = "minimax-api-token"

    func loadToken() throws -> String? {
        guard !KeychainAccessGate.isDisabled else {
            Self.log.debug("Keychain access disabled; skipping token load")
            return nil
        }
        if let token = try self.loadToken(service: self.service) {
            return token
        }
        return try self.loadToken(service: self.legacyService)
    }

    func storeToken(_ token: String?) throws {
        guard !KeychainAccessGate.isDisabled else {
            Self.log.debug("Keychain access disabled; skipping token store")
            return
        }
        let cleaned = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned == nil || cleaned?.isEmpty == true {
            try self.deleteIfPresent()
            return
        }

        let data = cleaned!.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = KeychainSecurity.update(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            Self.log.error("Keychain update failed: \(updateStatus)")
            throw MiniMaxAPITokenStoreError.keychainStatus(updateStatus)
        }

        var addQuery = query
        for (key, value) in attributes {
            addQuery[key] = value
        }
        let addStatus = KeychainSecurity.add(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            Self.log.error("Keychain add failed: \(addStatus)")
            throw MiniMaxAPITokenStoreError.keychainStatus(addStatus)
        }
    }

    private func loadToken(service: String) throws -> String? {
        var result: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: self.account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        if case .interactionRequired = KeychainAccessPreflight
            .checkGenericPassword(service: service, account: self.account)
        {
            KeychainPromptHandler.handler?(KeychainPromptContext(
                kind: .minimaxToken,
                service: service,
                account: self.account))
        }

        let status = KeychainSecurity.copyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            Self.log.error("Keychain read failed: \(status)")
            throw MiniMaxAPITokenStoreError.keychainStatus(status)
        }

        guard let data = result as? Data else {
            throw MiniMaxAPITokenStoreError.invalidData
        }
        let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let token, !token.isEmpty {
            return token
        }
        return nil
    }

    private func deleteIfPresent() throws {
        guard !KeychainAccessGate.isDisabled else { return }
        for service in [self.service, self.legacyService] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: self.account,
            ]
            let status = KeychainSecurity.delete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                continue
            }
            Self.log.error("Keychain delete failed: \(status)")
            throw MiniMaxAPITokenStoreError.keychainStatus(status)
        }
    }
}
