import AgentsBarCore
import Foundation

extension Notification.Name {
    static let agentsbarOpenSettings = Notification.Name("agentsbarOpenSettings")
    static let agentsbarDebugBlinkNow = Notification.Name("agentsbarDebugBlinkNow")
    #if DEBUG
    static let agentsbarDebugSimulateMemoryPressure =
        Notification.Name("com.steipete.agentsbar.debug.simulateMemoryPressure")
    #endif
    static let agentsbarSessionLimitReset = Notification.Name("agentsbarSessionLimitReset")
    static let agentsbarWeeklyLimitReset = Notification.Name("agentsbarWeeklyLimitReset")
    static let agentsbarProviderConfigDidChange = Notification.Name("agentsbarProviderConfigDidChange")
    static let agentsbarQuotaWarningDidPost = Notification.Name("agentsbarQuotaWarningDidPost")
}

@MainActor
final class SessionLimitResetEvent: NSObject {
    let provider: UsageProvider
    let accountIdentifier: String
    let accountLabel: String?
    let usedPercent: Double

    init(provider: UsageProvider, accountIdentifier: String, accountLabel: String?, usedPercent: Double) {
        self.provider = provider
        self.accountIdentifier = accountIdentifier
        self.accountLabel = accountLabel
        self.usedPercent = usedPercent
    }
}

@MainActor
final class WeeklyLimitResetEvent: NSObject {
    let provider: UsageProvider
    let accountIdentifier: String
    let accountLabel: String?
    let usedPercent: Double

    init(provider: UsageProvider, accountIdentifier: String, accountLabel: String?, usedPercent: Double) {
        self.provider = provider
        self.accountIdentifier = accountIdentifier
        self.accountLabel = accountLabel
        self.usedPercent = usedPercent
    }
}

@MainActor
final class QuotaWarningPostedEvent: NSObject {
    let provider: UsageProvider
    let window: QuotaWarningWindow
    let threshold: Int
    let postedAt: Date

    init(provider: UsageProvider, window: QuotaWarningWindow, threshold: Int, postedAt: Date) {
        self.provider = provider
        self.window = window
        self.threshold = threshold
        self.postedAt = postedAt
    }
}
