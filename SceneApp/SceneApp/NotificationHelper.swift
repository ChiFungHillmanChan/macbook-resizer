import AppKit
import UserNotifications

final class NotificationHelper {
    private let statusItem: () -> NSStatusItem?

    init(statusItem: @escaping () -> NSStatusItem?) {
        self.statusItem = statusItem
    }

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    func notifyNoWindows() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    self.postUN(
                        title: String(localized: "about.app_name"),
                        body: String(localized: "notification.no_windows")
                    )
                } else {
                    self.blinkStatusItem()
                }
            }
        }
    }

    /// Posts a banner with the given title + body when notifications are
    /// authorized; otherwise blinks the status item. Used by V0.4
    /// `WorkspaceActivator` for activation banners and quit-survivor warnings.
    func notify(title: String, body: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    self.postUN(title: title, body: body)
                } else {
                    self.blinkStatusItem()
                }
            }
        }
    }

    private func postUN(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    @MainActor
    private func blinkStatusItem() {
        guard let item = statusItem(), let button = item.button else { return }
        let oldAlpha = button.alphaValue
        let oldTooltip = button.toolTip
        button.toolTip = String(localized: "notification.no_windows")
        button.alphaValue = 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            button.alphaValue = oldAlpha
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            button.toolTip = oldTooltip
        }
    }
}
