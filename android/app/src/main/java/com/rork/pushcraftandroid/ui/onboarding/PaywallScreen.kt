package com.rork.pushcraftandroid.ui.onboarding

import android.app.Activity
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.rork.pushcraftandroid.R
import com.rork.pushcraftandroid.data.AppState
import com.rork.pushcraftandroid.data.Haptics
import com.rork.pushcraftandroid.data.StoreService
import com.rork.pushcraftandroid.ui.components.pressScale
import com.rork.pushcraftandroid.ui.theme.Pc
import com.rork.pushcraftandroid.ui.theme.rounded
import kotlinx.coroutines.launch

/** Hard paywall shown to signed-in users without an active subscription. */
@Composable
fun PaywallScreen(appState: AppState) {
    val store = appState.store
    val state by store.state.collectAsState()
    var yearly by remember { mutableStateOf(false) }
    var alert by remember { mutableStateOf<Pair<String, String>?>(null) }
    val scope = rememberCoroutineScope()
    val activity = LocalContext.current as? Activity
    val uri = LocalUriHandler.current
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        appeared = true
        if (state.weekly == null && state.yearly == null && !state.isLoadingOfferings) store.loadOfferings()
    }
    val a by animateFloatAsState(if (appeared) 1f else 0f, spring(dampingRatio = 0.85f, stiffness = 120f), label = "pw")
    val weeklyPrice = state.weekly?.product?.price?.formatted ?: "—"
    val yearlyPrice = state.yearly?.product?.price?.formatted ?: "—"
    val selected = if (yearly) state.yearly else state.weekly
    val busy = state.isPurchasing || state.isRestoring

    val features = listOf(
        Triple(R.drawable.paywall_swords, "Compete in Battles", "Challenge other players and test your strength."),
        Triple(R.drawable.paywall_tower, "Build Your Tower", "Break blocks with push-ups and watch your tower rise."),
        Triple(R.drawable.paywall_dumbbell, "Customized Workout Plan", "Workouts tailored to your fitness level."),
        Triple(R.drawable.paywall_ai_push, "AI Push-Up Tracking", "Reps counted automatically.")
    )

    Box(
        Modifier.fillMaxSize().background(Pc.paywallBg)
            .background(Brush.radialGradient(listOf(Color(0x8C1C3463), Color.Transparent), center = androidx.compose.ui.geometry.Offset(540f, 0f), radius = 1100f))
    ) {
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp).alpha(a).offset(y = (16 * (1 - a)).dp)
        ) {
            Column(Modifier.fillMaxWidth().padding(top = 28.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Get Stronger with", style = rounded(36, FontWeight.ExtraBold), color = Color.White)
                Text("Pushcraft", style = rounded(36, FontWeight.ExtraBold), color = Pc.paywallGold)
            }
            Column(Modifier.padding(top = 26.dp)) {
                features.forEachIndexed { i, (img, title, sub) ->
                    Row(Modifier.padding(vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Image(painterResource(img), null, Modifier.size(50.dp))
                        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(title, style = rounded(18, FontWeight.Bold), color = Color.White)
                            Text(sub, style = rounded(15, FontWeight.Medium), color = Pc.mist)
                        }
                    }
                    if (i < features.lastIndex) Box(Modifier.padding(start = 66.dp).fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.1f)))
                }
            }
            Column(Modifier.padding(top = 26.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                PlanCard(!yearly, "Weekly", "Billed weekly", "$weeklyPrice/week") { if (yearly) { Haptics.selection(); yearly = false } }
                PlanCard(yearly, "Yearly", "Billed annually", "$yearlyPrice/year") { if (!yearly) { Haptics.selection(); yearly = true } }
            }
            state.offeringsError?.let { err ->
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 44.dp).padding(top = 6.dp).pressScale { scope.launch { store.loadOfferings() } },
                    horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Filled.Refresh, null, tint = Pc.amberSoft, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.size(6.dp))
                    Text("$err Tap to retry.", style = rounded(13, FontWeight.SemiBold), color = Pc.amberSoft, textAlign = TextAlign.Center)
                }
            }
            val shape = RoundedCornerShape(18.dp)
            Box(
                Modifier.padding(top = 20.dp).fillMaxWidth().height(63.dp).alpha(if (selected == null) 0.5f else 1f)
                    .pressScale(selected != null && !busy) {
                        val pkg = selected ?: return@pressScale
                        val act = activity ?: return@pressScale
                        scope.launch {
                            when (val r = store.purchase(act, pkg)) {
                                StoreService.PurchaseOutcome.Success -> Haptics.success()
                                StoreService.PurchaseOutcome.Cancelled -> Unit
                                is StoreService.PurchaseOutcome.Failed -> { Haptics.warning(); alert = "Purchase didn't complete" to r.message }
                            }
                        }
                    }
            ) {
                Box(Modifier.fillMaxWidth().height(58.dp).offset(y = 5.dp).background(Pc.paywallGoldEdge, shape))
                Box(
                    Modifier.fillMaxWidth().height(58.dp).shadow(14.dp, shape, ambientColor = Pc.paywallGold, spotColor = Pc.paywallGold)
                        .background(Brush.verticalGradient(listOf(Pc.paywallGold, Pc.paywallGoldDeep)), shape),
                    contentAlignment = Alignment.Center
                ) {
                    if (state.isPurchasing) CircularProgressIndicator(Modifier.size(22.dp), color = Pc.paywallInk, strokeWidth = 2.5.dp)
                    else Text("Continue", style = rounded(20, FontWeight.ExtraBold), color = Pc.paywallInk)
                }
            }
            Column(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(if (yearly) "$yearlyPrice/year, billed annually." else "$weeklyPrice/week, billed weekly.", style = rounded(13, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.85f))
                Text("No commitment. Cancel anytime.", style = rounded(13, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.85f))
            }
            Row(
                Modifier.fillMaxWidth().heightIn(min = 44.dp).padding(top = 14.dp, bottom = 12.dp),
                horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically
            ) {
                if (state.isRestoring) CircularProgressIndicator(Modifier.size(18.dp), color = Pc.paywallGold, strokeWidth = 2.dp)
                else Text("Restore Purchases", style = rounded(14, FontWeight.SemiBold), color = Pc.mist, modifier = Modifier.pressScale(!busy) {
                    scope.launch {
                        when (val r = store.restore()) {
                            StoreService.RestoreOutcome.Restored -> Haptics.success()
                            StoreService.RestoreOutcome.NothingFound -> alert = "Nothing to restore" to "We couldn't find an active Pushcraft subscription for this account."
                            is StoreService.RestoreOutcome.Failed -> alert = "Restore failed" to r.message
                        }
                    }
                })
                Text("  ·  ", style = rounded(14, FontWeight.SemiBold), color = Pc.mist)
                Text("Terms", style = rounded(14, FontWeight.SemiBold), color = Pc.mist, modifier = Modifier.pressScale { uri.openUri("https://www.pushcraft.app/terms") })
                Text("  ·  ", style = rounded(14, FontWeight.SemiBold), color = Pc.mist)
                Text("Privacy", style = rounded(14, FontWeight.SemiBold), color = Pc.mist, modifier = Modifier.pressScale { uri.openUri("https://www.pushcraft.app/privacy-policy") })
            }
        }
    }
    alert?.let { (title, msg) ->
        AlertDialog(
            onDismissRequest = { alert = null }, containerColor = Pc.paywallBg,
            title = { Text(title, style = rounded(19, FontWeight.Bold), color = Pc.ivory) },
            text = { Text(msg, style = rounded(15, FontWeight.Medium), color = Pc.mist) },
            confirmButton = { TextButton({ alert = null }) { Text("OK", color = Pc.paywallGold) } }
        )
    }
}

@Composable
private fun PlanCard(selected: Boolean, title: String, subtitle: String, price: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    Row(
        Modifier.fillMaxWidth().heightIn(min = 84.dp)
            .shadow(if (selected) 14.dp else 0.dp, shape, ambientColor = Pc.paywallGold, spotColor = Pc.paywallGold)
            .background(Color(0xFF0F2040), shape)
            .border(if (selected) 2.5.dp else 1.5.dp, if (selected) Pc.paywallGold else Pc.paywallSlate, shape)
            .pressScale(onClick = onClick)
            .padding(18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(
            Modifier.size(28.dp).background(if (selected) Pc.paywallGold else Color.Transparent, CircleShape)
                .border(2.dp, if (selected) Pc.paywallGold else Pc.paywallSlate, CircleShape),
            contentAlignment = Alignment.Center
        ) { if (selected) Icon(Icons.Filled.Check, null, tint = Pc.paywallInk, modifier = Modifier.size(16.dp)) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = rounded(20, FontWeight.Bold), color = Color.White)
            Text(subtitle, style = rounded(15, FontWeight.Medium), color = Pc.mist)
        }
        Text(price, style = rounded(18, FontWeight.Bold), color = Color.White)
    }
}
