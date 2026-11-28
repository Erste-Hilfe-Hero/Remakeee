package de.chimora.appupdate;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;


import com.google.android.play.core.appupdate.AppUpdateInfo;
import com.google.android.play.core.appupdate.AppUpdateManager;
import com.google.android.play.core.appupdate.AppUpdateManagerFactory;
import com.google.android.play.core.appupdate.AppUpdateOptions;
import com.google.android.play.core.install.InstallStateUpdatedListener;
import com.google.android.play.core.install.model.AppUpdateType;
import com.google.android.play.core.install.model.InstallStatus;
import com.google.android.play.core.install.model.UpdateAvailability;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashSet;
import java.util.Set;

/**
 * Google Play in-app updates for Chimora (docs/LIVE_CONTENT.md, "Android in-app updates").
 * Every answer goes to Godot as one signal, "update_event", with a JSON text {"kind", ...}.
 * scripts/online/AppUpdater.gd reads it; scripts/online/AppUpdate.gd decides what to do.
 */
public class ChimoraAppUpdate extends GodotPlugin {
    private static final int REQUEST_UPDATE = 7301;

    private AppUpdateManager manager;
    private AppUpdateInfo lastInfo;
    private final InstallStateUpdatedListener listener = state -> {
        JSONObject o = new JSONObject();
        try {
            o.put("status", state.installStatus());
            o.put("bytes", state.bytesDownloaded());
            o.put("total", state.totalBytesToDownload());
            o.put("error", state.installErrorCode());
        } catch (JSONException ignored) {
        }
        send("progress", o);
    };

    public ChimoraAppUpdate(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "ChimoraAppUpdate";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> s = new HashSet<>();
        s.add(new SignalInfo("update_event", String.class));
        return s;
    }

    private void send(String kind, JSONObject o) {
        try {
            o.put("kind", kind);
            emitSignal("update_event", o.toString());
        } catch (JSONException e) {
            emitSignal("update_event", "{\"kind\":\"" + kind + "\"}");
        }
    }

    private AppUpdateManager manager() {
        if (manager == null) {
            Activity activity = getActivity();
            if (activity == null) {
                return null;
            }
            manager = AppUpdateManagerFactory.create(activity.getApplicationContext());
            manager.registerListener(listener);
        }
        return manager;
    }

    /** The package that installed the game ("com.android.vending" for Google Play, "" if unknown). */
    @UsedByGodot
    public String installer() {
        Activity activity = getActivity();
        if (activity == null) {
            return "";
        }
        try {
            Context c = activity.getApplicationContext();
            PackageManager pm = c.getPackageManager();
            String name;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                name = pm.getInstallSourceInfo(c.getPackageName()).getInstallingPackageName();
            } else {
                name = pm.getInstallerPackageName(c.getPackageName());
            }
            return name != null ? name : "";
        } catch (Exception e) {
            return "";
        }
    }

    /** Asks Play for an update. Answers {"kind": "info", "ok", "available", "in_progress", "downloaded", "immediate", "flexible", ...}. */
    @UsedByGodot
    public void check() {
        AppUpdateManager m = manager();
        if (m == null) {
            send("info", fail("no_activity"));
            return;
        }
        m.getAppUpdateInfo().addOnSuccessListener(info -> {
            lastInfo = info;
            JSONObject o = new JSONObject();
            try {
                int a = info.updateAvailability();
                o.put("ok", true);
                o.put("available", a == UpdateAvailability.UPDATE_AVAILABLE);
                o.put("in_progress", a == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS);
                o.put("downloaded", info.installStatus() == InstallStatus.DOWNLOADED);
                o.put("immediate", info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE));
                o.put("flexible", info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE));
                o.put("version_code", info.availableVersionCode());
                o.put("priority", info.updatePriority());
                Integer days = info.clientVersionStalenessDays();
                o.put("staleness_days", days != null ? days : -1);
            } catch (JSONException ignored) {
            }
            send("info", o);
        }).addOnFailureListener(e -> send("info", fail(String.valueOf(e.getMessage()))));
    }

    /** Starts Google's update screen for the last check: immediate (full screen) or flexible (download in the background). */
    @UsedByGodot
    public boolean start(boolean immediate) {
        AppUpdateManager m = manager();
        Activity activity = getActivity();
        if (m == null || activity == null || lastInfo == null) {
            return false;
        }
        int type = immediate ? AppUpdateType.IMMEDIATE : AppUpdateType.FLEXIBLE;
        try {
            return m.startUpdateFlowForResult(lastInfo, activity, AppUpdateOptions.newBuilder(type).build(), REQUEST_UPDATE);
        } catch (Exception e) {
            return false;
        } finally {
            // An AppUpdateInfo can start one flow only; the next start needs a new check().
            lastInfo = null;
        }
    }

    /** A flexible update is downloaded: install it now. Play restarts the game. */
    @UsedByGodot
    public void complete() {
        AppUpdateManager m = manager();
        if (m != null) {
            m.completeUpdate();
        }
    }

    @Override
    public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != REQUEST_UPDATE) {
            return;
        }
        JSONObject o = new JSONObject();
        try {
            // Activity.RESULT_OK (-1), RESULT_CANCELED (0), ActivityResult.RESULT_IN_APP_UPDATE_FAILED (1).
            o.put("result", resultCode);
        } catch (JSONException ignored) {
        }
        send("flow", o);
    }

    @Override
    public void onMainDestroy() {
        if (manager != null) {
            manager.unregisterListener(listener);
        }
    }

    private static JSONObject fail(String why) {
        JSONObject o = new JSONObject();
        try {
            o.put("ok", false);
            o.put("error", why);
        } catch (JSONException ignored) {
        }
        return o;
    }
}
