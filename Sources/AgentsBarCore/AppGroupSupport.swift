import Foundation
#if os(macOS)
import Security
#endif

public enum AppGroupSupport {
    public static let defaultTeamID = "Y5PE65HELJ"
    public static let teamIDInfoKey = "AgentsBarTeamID"
    public static let legacyReleaseGroupID = "group.com.steipete.codexbar"
    public static let legacyDebugGroupID = "group.com.steipete.codexbar.debug"
    public static let widgetSnapshotFilename = "widget-snapshot.json"
    public static let migrationVersion = 1
    public static let migrationVersionKey = "appGroupMigrationVersion"
    private static let sharedDefaultsMigrationKeys = [
        "debugDisableKeychainAccess",
        "widgetSelectedProvider",
    ]

    public struct MigrationResult: Sendable {
        public enum Status: String, Sendable {
            case alreadyCompleted
            case targetUnavailable
            case noChangesNeeded
            case migrated
        }

        public let status: Status
        public let copiedSnapshot: Bool
        public let copiedDefaults: Int

        public init(status: Status, copiedSnapshot: Bool = false, copiedDefaults: Int = 0) {
            self.status = status
            self.copiedSnapshot = copiedSnapshot
            self.copiedDefaults = copiedDefaults
        }
    }

    public static func currentGroupID(for bundleID: String? = Bundle.main.bundleIdentifier) -> String {
        self.currentGroupID(teamID: self.resolvedTeamID(), bundleID: bundleID)
    }

    static func currentGroupID(teamID: String, bundleID: String?) -> String {
        let base = "\(teamID).com.steipete.agentsbar"
        return self.isDebugBundleID(bundleID) ? "\(base).debug" : base
    }

    public static func resolvedTeamID(bundle: Bundle = .main) -> String {
        self.resolvedTeamID(
            infoDictionaryOverride: bundle.infoDictionary,
            bundleURLOverride: bundle.bundleURL)
    }

    static func resolvedTeamID(
        infoDictionaryOverride: [String: Any]?,
        bundleURLOverride: URL?) -> String
    {
        if let teamID = self.codeSignatureTeamID(bundleURL: bundleURLOverride) {
            return teamID
        }
        if let teamID = infoDictionaryOverride?[self.teamIDInfoKey] as? String,
           !teamID.isEmpty
        {
            return teamID
        }
        return self.defaultTeamID
    }

    public static func legacyGroupID(for bundleID: String? = Bundle.main.bundleIdentifier) -> String {
        self.isDebugBundleID(bundleID) ? self.legacyDebugGroupID : self.legacyReleaseGroupID
    }

    static func legacyTeamPrefixedGroupID(teamID: String, bundleID: String?) -> String {
        let base = "\(teamID).com.steipete.codexbar"
        return self.isDebugBundleID(bundleID) ? "\(base).debug" : base
    }

    static func legacyGroupIDs(teamID: String, bundleID: String?) -> [String] {
        [
            self.legacyTeamPrefixedGroupID(teamID: teamID, bundleID: bundleID),
            self.legacyGroupID(for: bundleID),
        ]
    }

    public static func sharedDefaults(
        bundleID: String? = Bundle.main.bundleIdentifier,
        fileManager: FileManager = .default)
        -> UserDefaults?
    {
        guard self.currentContainerURL(bundleID: bundleID, fileManager: fileManager) != nil else { return nil }
        return UserDefaults(suiteName: self.currentGroupID(for: bundleID))
    }

    public static func currentContainerURL(
        bundleID: String? = Bundle.main.bundleIdentifier,
        fileManager: FileManager = .default)
        -> URL?
    {
        #if os(macOS)
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: self.currentGroupID(for: bundleID))
        #else
        nil
        #endif
    }

    public static func snapshotURL(
        bundleID: String? = Bundle.main.bundleIdentifier,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> URL
    {
        if let container = self.currentContainerURL(bundleID: bundleID, fileManager: fileManager) {
            return container.appendingPathComponent(self.widgetSnapshotFilename, isDirectory: false)
        }

        let directory = self.localFallbackDirectory(fileManager: fileManager, homeDirectory: homeDirectory)
        return directory.appendingPathComponent(self.widgetSnapshotFilename, isDirectory: false)
    }

    public static func localFallbackDirectory(
        fileManager: FileManager = .default,
        homeDirectory _: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> URL
    {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let agentsBarDirectory = base.appendingPathComponent("AgentsBar", isDirectory: true)
        let legacyCodexBarDirectory = base.appendingPathComponent("CodexBar", isDirectory: true)
        if !fileManager.fileExists(atPath: agentsBarDirectory.path),
           fileManager.fileExists(atPath: legacyCodexBarDirectory.path)
        {
            self.migrateLocalFallbackDirectoryIfNeeded(
                from: legacyCodexBarDirectory,
                to: agentsBarDirectory,
                fileManager: fileManager)
        }
        try? fileManager.createDirectory(at: agentsBarDirectory, withIntermediateDirectories: true)
        return agentsBarDirectory
    }

    public static func legacyContainerCandidateURL(
        bundleID: String? = Bundle.main.bundleIdentifier,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> URL
    {
        self.legacyContainerCandidateURL(
            groupID: self.legacyGroupID(for: bundleID),
            homeDirectory: homeDirectory)
    }

    static func legacyContainerCandidateURL(groupID: String, homeDirectory: URL) -> URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Group Containers", isDirectory: true)
            .appendingPathComponent(groupID, isDirectory: true)
    }

    public static func migrateLegacyDataIfNeeded(
        bundleID: String? = Bundle.main.bundleIdentifier,
        standardDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        currentDefaultsOverride: UserDefaults? = nil,
        legacyDefaultsOverride: UserDefaults? = nil,
        currentSnapshotURLOverride: URL? = nil,
        legacySnapshotURLOverride: URL? = nil)
        -> MigrationResult
    {
        if standardDefaults.integer(forKey: self.migrationVersionKey) >= self.migrationVersion {
            return MigrationResult(status: .alreadyCompleted)
        }

        guard let currentDefaults = currentDefaultsOverride ?? self.sharedDefaults(
            bundleID: bundleID,
            fileManager: fileManager)
        else {
            return MigrationResult(status: .targetUnavailable)
        }

        let currentSnapshotURL = currentSnapshotURLOverride
            ?? self.currentContainerURL(bundleID: bundleID, fileManager: fileManager)?
            .appendingPathComponent(self.widgetSnapshotFilename, isDirectory: false)
        let legacySnapshotURL = legacySnapshotURLOverride
            ?? self.legacySnapshotCandidateURL(bundleID: bundleID, homeDirectory: homeDirectory)

        let copiedSnapshot = {
            guard let currentSnapshotURL else { return false }
            guard !fileManager.fileExists(atPath: currentSnapshotURL.path),
                  fileManager.fileExists(atPath: legacySnapshotURL.path)
            else {
                return false
            }
            do {
                try fileManager.createDirectory(
                    at: currentSnapshotURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try fileManager.copyItem(at: legacySnapshotURL, to: currentSnapshotURL)
                return true
            } catch {
                return false
            }
        }()

        let copiedDefaults: Int
        if let legacyDefaultsOverride {
            copiedDefaults = self.copyLegacySharedDefaults(
                from: legacyDefaultsOverride,
                to: currentDefaults)
        } else {
            copiedDefaults = self.copyLegacySharedDefaults(
                bundleID: bundleID,
                to: currentDefaults)
        }

        let result = if copiedSnapshot || copiedDefaults > 0 {
            MigrationResult(
                status: .migrated,
                copiedSnapshot: copiedSnapshot,
                copiedDefaults: copiedDefaults)
        } else {
            MigrationResult(status: .noChangesNeeded)
        }

        standardDefaults.set(self.migrationVersion, forKey: self.migrationVersionKey)
        return result
    }

    private static func copyLegacySharedDefaults(
        bundleID: String?,
        to currentDefaults: UserDefaults) -> Int
    {
        let teamID = self.resolvedTeamID()
        var copied = 0
        for groupID in self.legacyGroupIDs(teamID: teamID, bundleID: bundleID) {
            guard let legacyDefaults = UserDefaults(suiteName: groupID) else { continue }
            copied += self.copyLegacySharedDefaults(from: legacyDefaults, to: currentDefaults)
        }
        return copied
    }

    private static func legacySnapshotCandidateURL(
        bundleID: String?,
        homeDirectory: URL) -> URL
    {
        let teamID = self.resolvedTeamID()
        for groupID in self.legacyGroupIDs(teamID: teamID, bundleID: bundleID) {
            let snapshotURL = self.legacyContainerCandidateURL(groupID: groupID, homeDirectory: homeDirectory)
                .appendingPathComponent(self.widgetSnapshotFilename, isDirectory: false)
            if FileManager.default.fileExists(atPath: snapshotURL.path) {
                return snapshotURL
            }
        }

        return self.legacyContainerCandidateURL(bundleID: bundleID, homeDirectory: homeDirectory)
            .appendingPathComponent(self.widgetSnapshotFilename, isDirectory: false)
    }

    private static func migrateLocalFallbackDirectoryIfNeeded(
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        fileManager: FileManager)
    {
        do {
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            let contents = try fileManager.contentsOfDirectory(
                at: sourceDirectory,
                includingPropertiesForKeys: nil)
            for item in contents {
                let destination = destinationDirectory.appendingPathComponent(item.lastPathComponent, isDirectory: false)
                guard !fileManager.fileExists(atPath: destination.path) else { continue }
                try fileManager.copyItem(at: item, to: destination)
            }
        } catch {
            return
        }
    }

    private static func copyLegacySharedDefaults(
        from legacyDefaults: UserDefaults?,
        to currentDefaults: UserDefaults) -> Int
    {
        guard let legacyDefaults else { return 0 }

        var copied = 0
        for key in self.sharedDefaultsMigrationKeys {
            guard currentDefaults.object(forKey: key) == nil,
                  let legacyValue = legacyDefaults.object(forKey: key)
            else {
                continue
            }
            currentDefaults.set(legacyValue, forKey: key)
            copied += 1
        }
        return copied
    }

    private static func isDebugBundleID(_ bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return false }
        return bundleID.contains(".debug")
    }

    private static func codeSignatureTeamID(bundleURL: URL?) -> String? {
        #if os(macOS)
        guard let bundleURL else { return nil }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
              let code = staticCode
        else {
            return nil
        }

        var infoCF: CFDictionary?
        guard SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &infoCF) == errSecSuccess,
            let info = infoCF as? [String: Any],
            let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String,
            !teamID.isEmpty
        else {
            return nil
        }
        return teamID
        #else
        _ = bundleURL
        return nil
        #endif
    }
}
