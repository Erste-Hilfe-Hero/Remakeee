package de.chimora.billing;

import android.app.Activity;

import androidx.annotation.NonNull;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Google Play Billing for Chimora (plan area 10). Every answer goes to Godot as one signal,
 * "billing_event", with a JSON text: {"kind", "req", "code", ...}. scripts/shop/GoogleBillingStore.gd
 * reads it. The game never decides a purchase is valid: it sends the purchase token to the server
 * (server/billing), and only after the server credited it calls finish() to consume or acknowledge.
 */
public class ChimoraBilling extends GodotPlugin implements PurchasesUpdatedListener {
    private BillingClient client;
    private final Map<String, ProductDetails> details = new ConcurrentHashMap<>();
    private int purchaseReq = -1;

    public ChimoraBilling(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "ChimoraBilling";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> s = new HashSet<>();
        s.add(new SignalInfo("billing_event", String.class));
        return s;
    }

    private void send(String kind, int req, BillingResult r, JSONObject extra) {
        try {
            JSONObject o = extra != null ? extra : new JSONObject();
            o.put("kind", kind);
            o.put("req", req);
            if (r != null) {
                o.put("code", r.getResponseCode());
                o.put("message", r.getDebugMessage());
            } else if (!o.has("code")) {
                o.put("code", 0);
            }
            emitSignal("billing_event", o.toString());
        } catch (JSONException e) {
            emitSignal("billing_event", "{\"kind\":\"" + kind + "\",\"req\":" + req + ",\"code\":6}");
        }
    }

    private static boolean isSub(String productId) {
        return productId.endsWith(".pass") || productId.contains(".sub.");
    }

    @UsedByGodot
    public void start(int req) {
        Activity activity = getActivity();
        if (activity == null) {
            send("ready", req, null, error(3));
            return;
        }
        if (client == null) {
            client = BillingClient.newBuilder(activity)
                    .setListener(this)
                    .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
                    .build();
        }
        if (client.isReady()) {
            send("ready", req, null, null);
            return;
        }
        client.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(@NonNull BillingResult r) {
                send("ready", req, r, null);
            }

            @Override
            public void onBillingServiceDisconnected() {
                send("disconnected", -1, null, null);
            }
        });
    }

    private static JSONObject error(int code) {
        JSONObject o = new JSONObject();
        try {
            o.put("code", code);
        } catch (JSONException ignored) {
        }
        return o;
    }

    /** Store prices for a JSON list of product ids: {"prices": {id: "2,99 €"}}. */
    @UsedByGodot
    public void query(String idsJson, int req) {
        if (client == null || !client.isReady()) {
            send("prices", req, null, error(-1));
            return;
        }
        List<QueryProductDetailsParams.Product> inapp = new ArrayList<>();
        List<QueryProductDetailsParams.Product> subs = new ArrayList<>();
        try {
            JSONArray ids = new JSONArray(idsJson);
            for (int i = 0; i < ids.length(); i++) {
                String id = ids.getString(i);
                boolean sub = isSub(id);
                (sub ? subs : inapp).add(QueryProductDetailsParams.Product.newBuilder().setProductId(id)
                        .setProductType(sub ? BillingClient.ProductType.SUBS : BillingClient.ProductType.INAPP).build());
            }
        } catch (JSONException e) {
            send("prices", req, null, error(5));
            return;
        }
        JSONObject prices = new JSONObject();
        queryList(inapp, prices, () -> queryList(subs, prices, () -> {
            JSONObject o = new JSONObject();
            try {
                o.put("prices", prices);
            } catch (JSONException ignored) {
            }
            send("prices", req, null, o);
        }));
    }

    private void queryList(List<QueryProductDetailsParams.Product> list, JSONObject prices, Runnable then) {
        if (list.isEmpty()) {
            then.run();
            return;
        }
        QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder().setProductList(list).build();
        client.queryProductDetailsAsync(params, (r, result) -> {
            for (ProductDetails pd : result.getProductDetailsList()) {
                details.put(pd.getProductId(), pd);
                try {
                    prices.put(pd.getProductId(), priceOf(pd));
                } catch (JSONException ignored) {
                }
            }
            then.run();
        });
    }

    private static String priceOf(ProductDetails pd) {
        if (pd.getOneTimePurchaseOfferDetails() != null) {
            return pd.getOneTimePurchaseOfferDetails().getFormattedPrice();
        }
        List<ProductDetails.SubscriptionOfferDetails> offers = pd.getSubscriptionOfferDetails();
        if (offers != null && !offers.isEmpty()) {
            List<ProductDetails.PricingPhase> phases = offers.get(0).getPricingPhases().getPricingPhaseList();
            if (!phases.isEmpty()) {
                return phases.get(phases.size() - 1).getFormattedPrice();
            }
        }
        return "";
    }

    /** Opens Google's purchase sheet. The answer comes as "purchase" from onPurchasesUpdated. */
    @UsedByGodot
    public void purchase(String productId, String accountHash, int req) {
        ProductDetails pd = details.get(productId);
        Activity activity = getActivity();
        if (client == null || !client.isReady() || pd == null || activity == null) {
            send("purchase", req, null, error(4));
            return;
        }
        BillingFlowParams.ProductDetailsParams.Builder p = BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(pd);
        List<ProductDetails.SubscriptionOfferDetails> offers = pd.getSubscriptionOfferDetails();
        if (offers != null && !offers.isEmpty()) {
            p.setOfferToken(offers.get(0).getOfferToken());
        }
        BillingFlowParams flow = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(Collections.singletonList(p.build()))
                // The server compares this with sha256(account id) (server/billing/google.py).
                .setObfuscatedAccountId(accountHash)
                .build();
        purchaseReq = req;
        activity.runOnUiThread(() -> {
            BillingResult r = client.launchBillingFlow(activity, flow);
            if (r.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                purchaseReq = -1;
                send("purchase", req, r, null);
            }
        });
    }

    @Override
    public void onPurchasesUpdated(@NonNull BillingResult r, List<Purchase> purchases) {
        JSONObject o = new JSONObject();
        try {
            o.put("purchases", toJson(purchases));
        } catch (JSONException ignored) {
        }
        int req = purchaseReq;
        purchaseReq = -1;
        send("purchase", req, r, o);
    }

    private static JSONArray toJson(List<Purchase> purchases) throws JSONException {
        JSONArray a = new JSONArray();
        if (purchases == null) {
            return a;
        }
        for (Purchase p : purchases) {
            JSONObject o = new JSONObject();
            o.put("token", p.getPurchaseToken());
            o.put("order", p.getOrderId() != null ? p.getOrderId() : "");
            o.put("products", new JSONArray(p.getProducts()));
            o.put("state", p.getPurchaseState());
            o.put("acknowledged", p.isAcknowledged());
            o.put("account", p.getAccountIdentifiers() != null && p.getAccountIdentifiers().getObfuscatedAccountId() != null
                    ? p.getAccountIdentifiers().getObfuscatedAccountId() : "");
            a.put(o);
        }
        return a;
    }

    /** Purchases Google still holds (not consumed), one-time products and the pass. */
    @UsedByGodot
    public void owned(int req) {
        if (client == null || !client.isReady()) {
            send("owned", req, null, error(-1));
            return;
        }
        List<Purchase> all = Collections.synchronizedList(new ArrayList<>());
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
                (r1, inapp) -> {
                    all.addAll(inapp);
                    client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build(),
                            (r2, subs) -> {
                                all.addAll(subs);
                                JSONObject o = new JSONObject();
                                try {
                                    o.put("purchases", toJson(all));
                                } catch (JSONException ignored) {
                                }
                                send("owned", req, r2, o);
                            });
                });
    }

    /** After the server credited it: consume (bag items, Riftglass) or acknowledge (unlocks, pass). */
    @UsedByGodot
    public void finish(String token, boolean consume, int req) {
        if (client == null || !client.isReady()) {
            send("finished", req, null, error(-1));
            return;
        }
        if (consume) {
            client.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(token).build(),
                    (r, t) -> send("finished", req, r, null));
        } else {
            client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(token).build(),
                    r -> send("finished", req, r, null));
        }
    }
}
