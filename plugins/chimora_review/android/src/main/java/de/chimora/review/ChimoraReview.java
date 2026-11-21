package de.chimora.review;

import android.app.Activity;

import com.google.android.play.core.review.ReviewInfo;
import com.google.android.play.core.review.ReviewManager;
import com.google.android.play.core.review.ReviewManagerFactory;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Google Play In-App Review for Chimora (plan Chimora 100, item 75). scripts/online/ReviewAsk.gd
 * decides when; Play decides whether the sheet shows (quota) and never tells the game whether or
 * how the player rated, so there is nothing to answer.
 */
public class ChimoraReview extends GodotPlugin {
    private ReviewManager manager;

    public ChimoraReview(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "ChimoraReview";
    }

    /** Asks Play for the review sheet and shows it over the game when Play hands one out. */
    @UsedByGodot
    public void request_review() {
        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        activity.runOnUiThread(() -> {
            if (manager == null) {
                manager = ReviewManagerFactory.create(activity.getApplicationContext());
            }
            manager.requestReviewFlow().addOnCompleteListener(task -> {
                if (!task.isSuccessful()) {
                    return;
                }
                ReviewInfo info = task.getResult();
                manager.launchReviewFlow(activity, info);
            });
        });
    }
}
