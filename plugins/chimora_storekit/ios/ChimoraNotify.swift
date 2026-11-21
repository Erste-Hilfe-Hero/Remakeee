// Opt-in local notifications on iOS (plan Chimora 100, item 76): scheduled on the phone with
// UNUserNotificationCenter, no push server, nothing leaves the device. scripts/core/LocalNotify.gd
// decides what and when (two kinds only, never at night, at most one per kind and day) and calls
// ChimoraStoreKit.notify_* in chimora_storekit.cpp. The permission answer comes back as
// {"kind": "permission", "granted": bool} through the callback set by ck_notify_set_callback.
import Foundation
import UserNotifications

public typealias CKNotifyCallback = @convention(c) (UnsafePointer<CChar>) -> Void

enum CKNotify {
    nonisolated(unsafe) static var callback: CKNotifyCallback?
    static let prefix = "chimora_note_"

    static func emitPermission(_ granted: Bool) {
        let json = "{\"kind\":\"permission\",\"granted\":\(granted ? "true" : "false")}"
        DispatchQueue.main.async {
            guard let cb = callback else { return }
            json.withCString { cb($0) }
        }
    }
}

@_cdecl("ck_notify_set_callback")
public func ck_notify_set_callback(_ cb: CKNotifyCallback?) {
    CKNotify.callback = cb
}

/// The system prompt the first time; later calls answer at once with the current decision.
@_cdecl("ck_notify_request")
public func ck_notify_request() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
        CKNotify.emitPermission(granted)
    }
}

/// One note [delay] seconds from now. The same id replaces the earlier note of that kind.
@_cdecl("ck_notify_schedule")
public func ck_notify_schedule(_ id: Int64, _ title: UnsafePointer<CChar>, _ body: UnsafePointer<CChar>, _ delay: Int64) {
    let content = UNMutableNotificationContent()
    content.title = String(cString: title)
    content.body = String(cString: body)
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, delay)), repeats: false)
    let request = UNNotificationRequest(identifier: CKNotify.prefix + String(id), content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}

/// The app is open again: nothing planned stays, and shown notes leave the notification list.
@_cdecl("ck_notify_cancel_all")
public func ck_notify_cancel_all() {
    let center = UNUserNotificationCenter.current()
    center.removeAllPendingNotificationRequests()
    center.removeAllDeliveredNotifications()
}
