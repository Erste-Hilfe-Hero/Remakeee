// chimora:// links on iOS (scripts/core/DeepLink.gd). The app declares the URL type in
// export_presets.cfg (application/additional_plist_content). Godot's GDTApplicationDelegate hands
// scene and app callbacks to every registered service; this file adds one that keeps the last
// chimora:// URL until the game takes it with ChimoraStoreKit.take_url().
//
// The framework is linked into the app, so chimora_storekit.cpp calls ck_url_install before main,
// when Godot's service list does not exist yet. The service joins once the app finished launching,
// which is before UIKit connects the scene (a cold start brings the URL in its connection options).
import Foundation
import ObjectiveC
import UIKit

enum CKLinks {
    static let lock = NSLock()
    nonisolated(unsafe) static var pending = ""
    nonisolated(unsafe) static var observer: NSObjectProtocol?
    nonisolated(unsafe) static var service: CKLinkService?

    static func store(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "chimora" else { return false }
        lock.lock()
        pending = url.absoluteString
        lock.unlock()
        return true
    }
}

// Selectors as GDTApplicationDelegate calls them; it checks respondsToSelector first.
@MainActor
final class CKLinkService: NSObject {
    nonisolated override init() { super.init() }

    @objc(scene:willConnectToSession:options:)
    func sceneWillConnect(_ scene: UIScene, session: UISceneSession, options: UIScene.ConnectionOptions) {
        for c in options.urlContexts { _ = CKLinks.store(c.url) }
    }

    @objc(scene:openURLContexts:)
    func sceneOpen(_ scene: UIScene, contexts: Set<UIOpenURLContext>) {
        for c in contexts { _ = CKLinks.store(c.url) }
    }

    @objc(application:openURL:options:)
    func appOpen(_ app: UIApplication, url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return CKLinks.store(url)
    }
}

private typealias CKAddService = @convention(c) (AnyClass, Selector, AnyObject) -> Void

private func ckAddService() {
    guard CKLinks.service == nil, let cls = NSClassFromString("GDTApplicationDelegate") else { return }
    let sel = NSSelectorFromString("addService:")
    guard let m = class_getClassMethod(cls, sel) else { return }
    let svc = CKLinkService()
    CKLinks.service = svc
    unsafeBitCast(method_getImplementation(m), to: CKAddService.self)(cls, sel, svc)
    NSLog("ChimoraLinks: service added")
}

@_cdecl("ck_url_install")
public func ck_url_install() {
    guard CKLinks.observer == nil else { return }
    CKLinks.observer = NotificationCenter.default.addObserver(
        forName: NSNotification.Name("UIApplicationDidFinishLaunchingNotification"), object: nil, queue: nil
    ) { _ in ckAddService() }
}

/// The last chimora:// URL ("" when none), handed over once. The caller frees the string.
@_cdecl("ck_take_url")
public func ck_take_url() -> UnsafeMutablePointer<CChar>? {
    CKLinks.lock.lock()
    let s = CKLinks.pending
    CKLinks.pending = ""
    CKLinks.lock.unlock()
    return strdup(s)
}
