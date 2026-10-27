package com.tinochiwara.pushcraft.data

import android.app.Activity
import android.content.Context
import com.google.android.play.core.review.ReviewManagerFactory
import com.tinochiwara.pushcraft.PushcraftApplication

/**
 * Google Play In-App Review, mirroring the iOS review moments: the user's
 * first fully completed workout, and the onboarding first-reward result.
 * Fires at most once per install (the Play API also throttles its own
 * display); does nothing silently when not installed from Play.
 */
object ReviewPrompt {
    fun request(context: Context) {
        if (AppPreferences.hasAskedStoreReview) return
        AppPreferences.hasAskedStoreReview = true
        val activity = (context.applicationContext as? PushcraftApplication)?.currentActivity
            ?: return
        launch(activity)
    }

    private fun launch(activity: Activity) {
        runCatching {
            val manager = ReviewManagerFactory.create(activity)
            manager.requestReviewFlow().addOnCompleteListener { task ->
                if (!task.isSuccessful) return@addOnCompleteListener
                runCatching { manager.launchReviewFlow(activity, task.result) }
            }
        }
    }
}
