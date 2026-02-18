import AppKit
import Foundation
import Sparkle

/// Manages Sparkle-based in-app updates.
@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    private enum InfoPlistKeys {
        static let feedURL = "SUFeedURL"
        static let publicKey = "SUPublicEDKey"
    }

    private let updaterController: SPUStandardUpdaterController

    @Published private(set) var isConfigured = false
    @Published private(set) var isUpdaterRunning = false
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var feedURLString = ""

    var statusText: String {
        if !isConfigured {
            return "Not Configured"
        }
        if canCheckForUpdates {
            return "Ready"
        }
        if isUpdaterRunning {
            return "Starting..."
        }
        return "Unavailable"
    }

    var configurationHint: String {
        "Set SUFeedURL and SUPublicEDKey in Info.plist to enable in-app updates."
    }

    private override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        refreshConfiguration()

        if isConfigured {
            startUpdaterIfNeeded()
        } else {
            print("UpdateManager: Sparkle not configured. \(configurationHint)")
        }

        refreshStateFromUpdater()
    }

    /// Refresh update configuration from Info.plist.
    func refreshConfiguration() {
        let rawFeedURL = (Bundle.main.object(forInfoDictionaryKey: InfoPlistKeys.feedURL) as? String) ?? ""
        let rawPublicKey = (Bundle.main.object(forInfoDictionaryKey: InfoPlistKeys.publicKey) as? String) ?? ""

        let feed = rawFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = rawPublicKey.trimmingCharacters(in: .whitespacesAndNewlines)

        feedURLString = feed

        isConfigured = !feed.isEmpty &&
            !key.isEmpty &&
            !Self.isPlaceholderValue(feed) &&
            !Self.isPlaceholderValue(key)
    }

    /// Trigger a manual update check.
    func checkForUpdates() {
        guard ensureUpdaterReady(showAlertOnFailure: true) else { return }

        updaterController.checkForUpdates(nil)
        refreshStateFromUpdater()
    }

    /// Update Sparkle's automatic update-check preference.
    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard ensureUpdaterReady(showAlertOnFailure: false) else { return }

        updaterController.updater.automaticallyChecksForUpdates = enabled
        refreshStateFromUpdater()
    }

    /// Update Sparkle's automatic download preference.
    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        guard ensureUpdaterReady(showAlertOnFailure: false) else { return }

        updaterController.updater.automaticallyDownloadsUpdates = enabled
        refreshStateFromUpdater()
    }

    // MARK: - Private Helpers

    private func ensureUpdaterReady(showAlertOnFailure: Bool) -> Bool {
        refreshConfiguration()

        guard isConfigured else {
            if showAlertOnFailure {
                presentConfigurationAlert()
            }
            return false
        }

        startUpdaterIfNeeded()

        if !isUpdaterRunning && showAlertOnFailure {
            let alert = NSAlert()
            alert.messageText = "Updater Unavailable"
            alert.informativeText = lastErrorMessage ?? "Voxa couldn't start the updater. Check logs and signing configuration."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }

        return isUpdaterRunning
    }

    private func startUpdaterIfNeeded() {
        guard !isUpdaterRunning else { return }

        do {
            try updaterController.updater.start()
            isUpdaterRunning = true
            lastErrorMessage = nil
            print("UpdateManager: Sparkle updater started")
        } catch {
            isUpdaterRunning = false
            lastErrorMessage = "Failed to start updater: \(error.localizedDescription)"
            print("UpdateManager: \(lastErrorMessage ?? "Unknown updater start failure")")
        }
    }

    private func refreshStateFromUpdater() {
        let updater = updaterController.updater
        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }

    private static func isPlaceholderValue(_ value: String) -> Bool {
        let uppercased = value.uppercased()
        return uppercased.hasPrefix("REPLACE_WITH_") ||
            uppercased.contains("CHANGE_ME") ||
            uppercased.contains("EXAMPLE.COM")
    }

    private func presentConfigurationAlert() {
        let alert = NSAlert()
        alert.messageText = "Updates Not Configured"
        alert.informativeText = configurationHint
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
