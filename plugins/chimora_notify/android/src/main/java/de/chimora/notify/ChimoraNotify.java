package de.chimora.notify;

import android.Manifest;
import android.app.Activity;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/**
 * Opt-in local notifications for Chimora (plan Chimora 100, item 76). scripts/core/LocalNotify.gd
 * decides what and when; this plugin only plans each note with an inexact AlarmManager alarm (no
 * exact-alarm permission) and NotifyReceiver shows it. No push server, no network, no install code.
 * The permission answer comes back as {"kind": "permission", "granted": bool} on "notify_event".
 */
public class ChimoraNotify extends GodotPlugin {
    static final String PREFS = "chimora_notify";
    static final String KEY_IDS = "ids";
    private static final int REQUEST_CODE = 7601;
    private static final SignalInfo EVENT = new SignalInfo("notify_event", String.class);

    public ChimoraNotify(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "ChimoraNotify";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        return Collections.singleton(EVENT);
    }

    private Context context() {
        Activity a = getActivity();
        return a == null ? null : a.getApplicationContext();
    }

    /** Android 13+ asks the player; older versions answer with the app's notification switch. */
    @UsedByGodot
    public void notify_request_permission() {
        Activity a = getActivity();
        if (a == null) {
            return;
        }
        if (Build.VERSION.SDK_INT >= 33
                && ContextCompat.checkSelfPermission(a, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            a.runOnUiThread(() -> ActivityCompat.requestPermissions(a,
                    new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQUEST_CODE));
            return;
        }
        emitPermission(NotificationManagerCompat.from(a).areNotificationsEnabled());
    }

    @Override
    public void onMainRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode != REQUEST_CODE) {
            return;
        }
        emitPermission(grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED);
    }

    private void emitPermission(boolean granted) {
        emitSignal(EVENT.getName(), "{\"kind\":\"permission\",\"granted\":" + granted + "}");
    }

    /** One note [delay] seconds from now; the same id replaces the earlier note of that kind. */
    @UsedByGodot
    public void notify_schedule(int id, String title, String body, int delay) {
        Context c = context();
        if (c == null) {
            return;
        }
        Intent i = new Intent(c, NotifyReceiver.class)
                .putExtra(NotifyReceiver.EXTRA_ID, id)
                .putExtra(NotifyReceiver.EXTRA_TITLE, title)
                .putExtra(NotifyReceiver.EXTRA_BODY, body);
        PendingIntent pi = PendingIntent.getBroadcast(c, id, i,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (am == null) {
            return;
        }
        am.set(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + Math.max(1, delay) * 1000L, pi);
        SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        Set<String> ids = new HashSet<>(p.getStringSet(KEY_IDS, Collections.emptySet()));
        ids.add(String.valueOf(id));
        p.edit().putStringSet(KEY_IDS, ids).apply();
    }

    /** The app is open again: nothing planned stays, and shown notes leave the shade. */
    @UsedByGodot
    public void notify_cancel_all() {
        Context c = context();
        if (c == null) {
            return;
        }
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        for (String s : p.getStringSet(KEY_IDS, Collections.emptySet())) {
            int id;
            try {
                id = Integer.parseInt(s);
            } catch (NumberFormatException e) {
                continue;
            }
            PendingIntent pi = PendingIntent.getBroadcast(c, id, new Intent(c, NotifyReceiver.class),
                    PendingIntent.FLAG_NO_CREATE | PendingIntent.FLAG_IMMUTABLE);
            if (pi != null && am != null) {
                am.cancel(pi);
                pi.cancel();
            }
        }
        p.edit().remove(KEY_IDS).apply();
        NotificationManagerCompat.from(c).cancelAll();
    }
}
