package com.tinochiwara.pushcraft

import android.app.Activity
import android.app.Application
import android.os.Bundle
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.tinochiwara.pushcraft.data.AppPreferences
import com.tinochiwara.pushcraft.data.AppState
import com.tinochiwara.pushcraft.data.Haptics
import com.tinochiwara.pushcraft.data.SoundService

class PushcraftApplication : Application() {
    lateinit var appState: AppState
        private set

    /// Foreground activity, needed by Credential Manager to show the
    /// native Google account-picker sheet.
    var currentActivity: Activity? = null
        private set

    override fun onCreate() {
        super.onCreate()
        AppPreferences.init(this)
        Haptics.init(this)
        SoundService.init(this)
        val key = Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY
        if (key.isNotBlank()) {
            Purchases.logLevel = LogLevel.WARN
            Purchases.configure(PurchasesConfiguration.Builder(this, key).build())
        }
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityResumed(activity: Activity) {
                currentActivity = activity
            }

            override fun onActivityDestroyed(activity: Activity) {
                if (currentActivity === activity) currentActivity = null
            }

            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityStarted(activity: Activity) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivityStopped(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        })
        appState = AppState(this)
        appState.start()
    }
}
