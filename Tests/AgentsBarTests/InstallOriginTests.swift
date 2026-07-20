import Foundation
import Testing
@testable import AgentsBar

struct InstallOriginTests {
    @Test
    func `detects homebrew caskroom`() {
        #expect(
            InstallOrigin
                .isHomebrewCask(
                    appBundleURL: URL(fileURLWithPath: "/opt/homebrew/Caskroom/agentsbar/1.0.0/AgentsBar.app")))
        #expect(
            InstallOrigin
                .isHomebrewCask(appBundleURL: URL(fileURLWithPath: "/usr/local/Caskroom/agentsbar/1.0.0/AgentsBar.app")))
        #expect(!InstallOrigin.isHomebrewCask(appBundleURL: URL(fileURLWithPath: "/Applications/AgentsBar.app")))
    }
}
