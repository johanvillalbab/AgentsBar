import Foundation

public enum AgentsBarConfigStoreError: LocalizedError {
    case invalidURL
    case decodeFailed(String)
    case encodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid AgentsBar config path."
        case let .decodeFailed(details):
            "Failed to decode AgentsBar config: \(details)"
        case let .encodeFailed(details):
            "Failed to encode AgentsBar config: \(details)"
        }
    }
}

public struct AgentsBarConfigStore: @unchecked Sendable {
    public static let pathEnvironmentKey = "AGENTSBAR_CONFIG"
    public static let legacyPathEnvironmentKey = "CODEXBAR_CONFIG"
    public static let xdgConfigHomeEnvironmentKey = "XDG_CONFIG_HOME"

    public let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL = Self.defaultURL(), fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> AgentsBarConfig? {
        guard self.fileManager.fileExists(atPath: self.fileURL.path) else { return nil }
        let data = try Data(contentsOf: self.fileURL)
        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode(AgentsBarConfig.self, from: data)
            return decoded.normalized()
        } catch {
            throw AgentsBarConfigStoreError.decodeFailed(error.localizedDescription)
        }
    }

    public func loadOrCreateDefault() throws -> AgentsBarConfig {
        if let existing = try self.load() {
            return existing
        }
        let config = AgentsBarConfig.makeDefault()
        try self.save(config)
        return config
    }

    public func save(_ config: AgentsBarConfig) throws {
        let normalized = config.normalized()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(normalized)
        } catch {
            throw AgentsBarConfigStoreError.encodeFailed(error.localizedDescription)
        }
        let directory = self.fileURL.deletingLastPathComponent()
        if !self.fileManager.fileExists(atPath: directory.path) {
            try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: self.fileURL, options: [.atomic])
        try self.applySecurePermissionsIfNeeded()
    }

    public func deleteIfPresent() throws {
        guard self.fileManager.fileExists(atPath: self.fileURL.path) else { return }
        try self.fileManager.removeItem(at: self.fileURL)
    }

    public static func defaultURL(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default) -> URL
    {
        if let override = environment[pathEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty
        {
            let expanded = (override as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }

        if let override = environment[legacyPathEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty
        {
            let expanded = (override as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }

        let agentsbarXDG = self.xdgConfigURL(home: home, environment: environment, segment: "agentsbar")
        let codexbarXDG = self.xdgConfigURL(home: home, environment: environment, segment: "codexbar")
        let dotCodexbar = home
            .appendingPathComponent(".codexbar", isDirectory: true)
            .appendingPathComponent("config.json")

        if fileManager.fileExists(atPath: agentsbarXDG.path) {
            return agentsbarXDG
        }

        if fileManager.fileExists(atPath: codexbarXDG.path) {
            return codexbarXDG
        }

        if fileManager.fileExists(atPath: dotCodexbar.path) {
            return dotCodexbar
        }

        return agentsbarXDG
    }

    private static func xdgConfigURL(
        home: URL,
        environment: [String: String],
        segment: String) -> URL
    {
        if let xdgConfigHome = environment[xdgConfigHomeEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !xdgConfigHome.isEmpty
        {
            let expanded = (xdgConfigHome as NSString).expandingTildeInPath
            if (expanded as NSString).isAbsolutePath {
                return URL(fileURLWithPath: expanded, isDirectory: true)
                    .appendingPathComponent(segment, isDirectory: true)
                    .appendingPathComponent("config.json")
            }
        }

        return home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent(segment, isDirectory: true)
            .appendingPathComponent("config.json")
    }

    private func applySecurePermissionsIfNeeded() throws {
        #if os(macOS) || os(Linux)
        try self.fileManager.setAttributes([
            .posixPermissions: NSNumber(value: Int16(0o600)),
        ], ofItemAtPath: self.fileURL.path)
        #endif
    }
}
