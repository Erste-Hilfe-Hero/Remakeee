package de.chimora.notify;

import android.Manifest;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

/** Shows one note planned by ChimoraNotify (plan Chimora 100, item 76). A tap opens the game. */
public class NotifyReceiver extends BroadcastReceiver {
    static final String EXTRA_ID = "id";
    static final String EXTRA_TITLE = "title";
    static final String EXTRA_BODY = "body";
    static final String CHANNEL = "chimora_notes";

    @Override
    public void onReceive(Context c, Intent intent) {
        if (Build.VERSION.SDK_INT >= 33
                && ContextCompat.checkSelfPermission(c, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return;
        }
        String title = intent.getStringExtra(EXTRA_TITLE);
        if (title == null) {
            title = "Chimora";
        }
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager nm = c.getSystemService(NotificationManager.class);
            if (nm != null) {
                nm.createNotificationChannel(new NotificationChannel(CHANNEL, title, NotificationManager.IMPORTANCE_DEFAULT));
            }
        }
        Intent launch = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
        PendingIntent open = launch == null ? null : PendingIntent.getActivity(c, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        String body = intent.getStringExtra(EXTRA_BODY);
        NotificationCompat.Builder b = new NotificationCompat.Builder(c, CHANNEL)
                .setSmallIcon(R.drawable.chimora_note)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true);
        if (open != null) {
            b.setContentIntent(open);
        }
        try {
            NotificationManagerCompat.from(c).notify(intent.getIntExtra(EXTRA_ID, 1), b.build());
        } catch (SecurityException e) {
            // Permission taken back between planning and showing: nothing to show.
        }
    }
}
