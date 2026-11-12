// Chimora's App Store purchases with StoreKit 2 (plan item 4092). Called from chimora_storekit.cpp, the
// GDExtension class "ChimoraStoreKit". Speaks the same JSON protocol as the Android plugin
// (plugins/chimora_billing): every call answers once with {"kind", "req", "code", ...} through the
// callback set by ck_set_callback. Codes follow Play Billing's BillingResponseCode so both stores
// share AppleBillingStore.gd/GoogleBillingStore.gd logic: 0 ok, 1 cancelled, 2 offline, 3 no store,
// 4 not available, 6 error, 7 already owned.
//
// Purchases carry appAccountToken = the player's account id, so the server (server/billing/apple.py)
// credits them to that account only. The client never trusts a purchase itself: it sends the signed
// transaction (JWS) to the server and finishes it only after the server credited it (item 4097).
import Foundation
import StoreKit

public typealias CKCallback = @convention(c) (UnsafePointer<CChar>) -> Void

@MainActor
final class CKState {
    static let shared = CKState()
    var callback: CKCallback?
    var products: [String: Product] = [:]
    /// Verified transactions the server has not credited yet, by transaction id.
    var open: [String: Transaction] = [:]
    var updates: Task<Void, Never>?

    func emit(_ d: [String: Any]) {
        guard let cb = callback,
              let data = try? JSONSerialization.data(withJSONObject: d),
              let s = String(data: data, encoding: .utf8) else { return }
        s.withCString { cb($0) }
    }

    func entry(_ v: VerificationResult<Transaction>, unfinished: Bool) -> [String: Any] {
        let t = v.unsafePayloadValue
        if case .verified(let vt) = v, unfinished { open[String(vt.id)] = vt }
        return ["product": t.productID, "jws": v.jwsRepresentation, "txn": String(t.id),
                "account": t.appAccountToken?.uuidString.lowercased() ?? "",
                "revoked": t.revocationDate != nil, "unfinished": unfinished,
                "verified": { if case .verified = v { return true } else { return false } }()]
    }

    func products(for ids: [String]) async -> [String: Product] {
        let missing = ids.filter { products[$0] == nil }
        if !missing.isEmpty, let found = try? await Product.products(for: missing) {
            for p in found { products[p.id] = p }
        }
        return products
    }

    /// Unfinished transactions first (bought, server not told yet), then what the player owns.
    func owned() async -> [[String: Any]] {
        var out: [[String: Any]] = []
        var seen = Set<String>()
        for await v in Transaction.unfinished {
            let e = entry(v, unfinished: true)
            if seen.insert(e["txn"] as! String).inserted { out.append(e) }
        }
        for await v in Transaction.currentEntitlements {
            let e = entry(v, unfinished: false)
            if seen.insert(e["txn"] as! String).inserted { out.append(e) }
        }
        return out
    }
}

@_cdecl("ck_set_callback")
public func ck_set_callback(_ cb: @escaping CKCallback) {
    Task { @MainActor in CKState.shared.callback = cb }
}

@_cdecl("ck_start")
public func ck_start(_ req: Int64) {
    Task { @MainActor in
        let s = CKState.shared
        if s.updates == nil {
            // Purchases finished outside the sheet (Ask to Buy, renewals, refunds, other devices).
            s.updates = Task { @MainActor in
                for await v in Transaction.updates {
                    s.emit(["kind": "update", "req": -1, "code": 0, "purchases": [s.entry(v, unfinished: true)]])
                }
            }
        }
        s.emit(["kind": "ready", "req": req, "code": AppStore.canMakePayments ? 0 : 3])
    }
}

@_cdecl("ck_query")
public func ck_query(_ idsJson: UnsafePointer<CChar>, _ req: Int64) {
    let ids = (try? JSONSerialization.jsonObject(with: Data(String(cString: idsJson).utf8))) as? [String] ?? []
    Task { @MainActor in
        let s = CKState.shared
        let found = await s.products(for: ids)
        var prices: [String: String] = [:]
        for id in ids { if let p = found[id] { prices[id] = p.displayPrice } }
        s.emit(["kind": "prices", "req": req, "code": prices.isEmpty && !ids.isEmpty ? 2 : 0, "prices": prices])
    }
}

@_cdecl("ck_purchase")
public func ck_purchase(_ pid: UnsafePointer<CChar>, _ token: UnsafePointer<CChar>, _ req: Int64) {
    let productId = String(cString: pid)
    let account = String(cString: token)
    Task { @MainActor in
        let s = CKState.shared
        guard let product = await s.products(for: [productId])[productId] else {
            s.emit(["kind": "purchase", "req": req, "code": 4]); return
        }
        var options: Set<Product.PurchaseOption> = []
        if let uuid = UUID(uuidString: account) { options.insert(.appAccountToken(uuid)) }
        do {
            switch try await product.purchase(options: options) {
            case .success(let v):
                s.emit(["kind": "purchase", "req": req, "code": 0, "purchases": [s.entry(v, unfinished: true)]])
            case .userCancelled:
                s.emit(["kind": "purchase", "req": req, "code": 1])
            case .pending:
                // Ask to Buy or a payment that needs more steps: it arrives later through updates.
                s.emit(["kind": "purchase", "req": req, "code": 0, "pending": true, "purchases": []])
            @unknown default:
                s.emit(["kind": "purchase", "req": req, "code": 6])
            }
        } catch {
            let code: Int
            if let e = error as? StoreKitError, case .networkError = e { code = 2 }
            else if let e = error as? Product.PurchaseError, case .productUnavailable = e { code = 4 }
            else { code = 6 }
            s.emit(["kind": "purchase", "req": req, "code": code, "error": String(describing: error).prefix(200).description])
        }
    }
}

@_cdecl("ck_finish")
public func ck_finish(_ txn: UnsafePointer<CChar>, _ req: Int64) {
    let id = String(cString: txn)
    Task { @MainActor in
        let s = CKState.shared
        if let t = s.open.removeValue(forKey: id) {
            await t.finish()
        } else {
            for await v in Transaction.unfinished where String(v.unsafePayloadValue.id) == id {
                if case .verified(let t) = v { await t.finish() }
            }
        }
        s.emit(["kind": "finished", "req": req, "code": 0, "txn": id])
    }
}

@_cdecl("ck_owned")
public func ck_owned(_ req: Int64) {
    Task { @MainActor in
        let s = CKState.shared
        s.emit(["kind": "owned", "req": req, "code": 0, "purchases": await s.owned()])
    }
}

/// "Restore purchases" (guideline 3.1.1): syncs with the App Store (may ask for the Apple ID password),
/// then answers like ck_owned.
@_cdecl("ck_restore")
public func ck_restore(_ req: Int64) {
    Task { @MainActor in
        let s = CKState.shared
        var code = 0
        do {
            try await AppStore.sync()
        } catch let e as StoreKitError {
            if case .userCancelled = e { code = 1 } else { code = 2 }
        } catch {
            code = 6
        }
        s.emit(["kind": "owned", "req": req, "code": code, "purchases": await s.owned()])
    }
}
