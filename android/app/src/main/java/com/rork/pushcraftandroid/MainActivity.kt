package com.rork.pushcraftandroid

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.rork.pushcraftandroid.data.Backend
import com.rork.pushcraftandroid.ui.RootView
import com.rork.pushcraftandroid.ui.theme.AppTheme
import io.github.jan.supabase.auth.handleDeeplinks
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private val appState get() = (application as PushcraftApplication).appState

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT)
        )
        handleAuthIntent(intent)
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                lifecycleScope.launch { appState.refresh() }
            }
        })
        setContent {
            AppTheme {
                RootView(appState)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAuthIntent(intent)
    }

    private fun handleAuthIntent(intent: Intent?) {
        if (intent?.data?.scheme == "pushcraft") {
            runCatching { Backend.client.handleDeeplinks(intent) }
        }
    }
}
