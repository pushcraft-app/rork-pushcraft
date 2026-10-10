package com.tinochiwara.pushcraft

import android.app.Application
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
        appState = AppState(this)
        appState.start()
    }
}
