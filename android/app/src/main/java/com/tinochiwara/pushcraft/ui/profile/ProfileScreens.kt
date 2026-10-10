package com.tinochiwara.pushcraft.ui.profile

import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Feedback
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarOutline
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.tinochiwara.pushcraft.R
import com.tinochiwara.pushcraft.data.AppPreferences
import com.tinochiwara.pushcraft.data.AppState
import com.tinochiwara.pushcraft.data.BackendFailure
import com.tinochiwara.pushcraft.data.Progress
import com.tinochiwara.pushcraft.data.Reminders
import com.tinochiwara.pushcraft.data.StoreService
import com.tinochiwara.pushcraft.ui.battles.formatDate
import com.tinochiwara.pushcraft.ui.components.AmberGradient
import com.tinochiwara.pushcraft.ui.components.FlameIcon
import com.tinochiwara.pushcraft.ui.components.GoldButton
import com.tinochiwara.pushcraft.ui.components.SectionLabel
import com.tinochiwara.pushcraft.ui.components.battleCard
import com.tinochiwara.pushcraft.ui.components.pressScale
import com.tinochiwara.pushcraft.ui.components.recessed
import com.tinochiwara.pushcraft.ui.theme.Pc
import com.tinochiwara.pushcraft.ui.theme.rounded
import com.tinochiwara.pushcraft.ui.theme.serif
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private enum class Sheet { Settings, Edit, Account, Subscription, Notifications, Haptics, Sound, Feedback }

/** Profile tab: avatar, name and lifetime stats; gear opens Settings. */
@Composable
fun ProfileScreen(appState: AppState, modifier: Modifier = Modifier) {
    val dashboard by appState.progress.dashboard.collectAsState()
    val avatar by appState.progress.avatar.collectAsState()
    val stats = dashboard?.stats
    var sheet by remember { mutableStateOf<Sheet?>(null) }
    var refreshing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    PullToRefreshBox(refreshing, { scope.launch { refreshing = true; appState.refresh(); refreshing = false } }, modifier.fillMaxSize().background(Pc.towersNavy)) {
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 28.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Profile", style = serif(34), color = Pc.ivory, modifier = Modifier.weight(1f))
                Box(Modifier.size(44.dp).pressScale { sheet = Sheet.Settings }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Settings, "Settings", tint = Pc.iconBlue, modifier = Modifier.size(24.dp))
                }
            }
            Column(Modifier.fillMaxWidth().padding(top = 28.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Avatar(avatar, 150.dp, Modifier.pressScale { sheet = Sheet.Edit })
                Text(dashboard?.profile?.displayName ?: " ", style = serif(24), color = Pc.ivory, maxLines = 1)
            }
            Column(Modifier.padding(top = 36.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Your stats", style = rounded(24, FontWeight.Bold), color = Pc.ivory)
                StatTile("${stats?.totalReps ?: 0}", "Total Reps") { Image(painterResource(R.drawable.stat_dumbbell), null, Modifier.size(30.dp)) }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatTile("${stats?.completedWorkouts ?: 0}", "Completed sessions", Modifier.weight(1f)) { Image(painterResource(R.drawable.stat_calendar), null, Modifier.size(30.dp)) }
                    StatTile("${stats?.completedTowers ?: 0}", "Completed towers", Modifier.weight(1f)) { Image(painterResource(R.drawable.stat_tower), null, Modifier.size(30.dp)) }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatTile("${Progress.displayStreak(dashboard)}", "Current streak", Modifier.weight(1f)) { FlameIcon(26.dp) }
                    StatTile("${stats?.coinsBalance ?: 0}", "Coins", Modifier.weight(1f), Pc.gold) { Image(painterResource(R.drawable.gold_coin_star), null, Modifier.size(26.dp)) }
                }
            }
        }
    }

    sheet?.let { s ->
        val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        val close = { sheet = if (s == Sheet.Settings || s == Sheet.Edit) null else Sheet.Settings }
        ModalBottomSheet(onDismissRequest = close, sheetState = state, containerColor = Pc.night, dragHandle = null) {
            when (s) {
                Sheet.Settings -> SettingsSheet(onClose = { sheet = null }) { sheet = it }
                Sheet.Edit -> EditProfileSheet(appState) { sheet = null }
                Sheet.Account -> AccountSheet(appState, close)
                Sheet.Subscription -> SubscriptionSheet(appState, close)
                Sheet.Notifications -> ToggleSheet(
                    "Notifications", Icons.Filled.Notifications,
                    "A reminder at ${AppPreferences.reminderTimeText} on your build days when you haven't completed a workout yet, so your streak stays alive. Sent by this phone.",
                    AppPreferences.notificationsFlow, { AppPreferences.notificationsEnabled = it; appState.scheduleReminders() }, close
                )
                Sheet.Haptics -> ToggleSheet("Haptic", Icons.Filled.TouchApp, "Controls impact and feedback vibrations across workouts and battles.", AppPreferences.hapticsFlow, { AppPreferences.hapticsEnabled = it }, close)
                Sheet.Sound -> ToggleSheet("Sound Effects", Icons.AutoMirrored.Filled.VolumeUp, "Controls game and interface sound effects.", AppPreferences.soundFlow, { AppPreferences.soundEnabled = it }, close)
                Sheet.Feedback -> FeedbackSheet(close)
            }
        }
    }
}

@Composable
private fun Avatar(bytes: ByteArray?, size: Dp, modifier: Modifier = Modifier) {
    val bitmap = remember(bytes) { bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size)?.asImageBitmap() } }
    Box(
        modifier.size(size).shadow(10.dp, CircleShape, ambientColor = Pc.amber, spotColor = Pc.amber).clip(CircleShape)
            .background(Brush.verticalGradient(listOf(Color(0xFF33456B), Color(0xFF1C2A47))))
            .border(3.dp, Pc.amberSoft, CircleShape),
        contentAlignment = Alignment.Center
    ) {
        if (bitmap != null) Image(bitmap, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        else Icon(Icons.Filled.Person, null, tint = Pc.mist, modifier = Modifier.size(size * 0.38f))
    }
}

@Composable
private fun StatTile(value: String, label: String, modifier: Modifier = Modifier.fillMaxWidth(), valueColor: Color = Pc.ivory, icon: @Composable () -> Unit) {
    Row(
        modifier.shadow(10.dp, RoundedCornerShape(22.dp)).battleCard().padding(16.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(Modifier.size(34.dp), contentAlignment = Alignment.Center) { icon() }
        Box(Modifier.width(1.dp).height(40.dp).background(Color.White.copy(alpha = 0.14f)))
        Column {
            Text(value, style = rounded(26, FontWeight.ExtraBold), color = valueColor, maxLines = 1)
            Text(label, style = rounded(13, FontWeight.Medium), color = Pc.mist, maxLines = 2)
        }
    }
}

@Composable
private fun SheetHeader(title: String, onClose: () -> Unit) {
    Column {
        Box(Modifier.padding(top = 10.dp).align(Alignment.CenterHorizontally).size(40.dp, 5.dp).background(Color.White.copy(alpha = 0.25f), CircleShape))
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 14.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = rounded(22, FontWeight.Bold), color = Pc.ivory, modifier = Modifier.weight(1f))
            Box(Modifier.size(32.dp).background(Color.White.copy(alpha = 0.08f), CircleShape).pressScale(onClick = onClose), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Close, "Close", tint = Pc.mist, modifier = Modifier.size(15.dp))
            }
        }
    }
}

@Composable
private fun SettingsSheet(onClose: () -> Unit, open: (Sheet) -> Unit) {
    val context = LocalContext.current
    var dialog by remember { mutableStateOf<Pair<String, String>?>(null) }
    fun url(u: String) = runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u))) }
    Column(Modifier.fillMaxSize()) {
        SheetHeader("Settings", onClose)
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Section("ACCOUNT") {
                SettingsRow("Account", Icons.Filled.AccountCircle) { open(Sheet.Account) }
                SettingsRow("Subscription", Icons.Filled.StarOutline) { open(Sheet.Subscription) }
            }
            Section("PREFERENCES") {
                SettingsRow("Notifications", Icons.Filled.Notifications) { open(Sheet.Notifications) }
                SettingsRow("Haptic", Icons.Filled.TouchApp) { open(Sheet.Haptics) }
                SettingsRow("Sound Effects", Icons.AutoMirrored.Filled.VolumeUp) { open(Sheet.Sound) }
            }
            Section("SUPPORT") {
                SettingsRow("Contact Support", Icons.Filled.Email) {
                    try {
                        context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:contact@pushcraft.app")))
                    } catch (_: ActivityNotFoundException) {
                        dialog = "Contact Support" to "No email app is available. Reach us at contact@pushcraft.app."
                    }
                }
            }
            Section("FEEDBACK") {
                SettingsRow("Provide Feedback", Icons.Filled.Feedback) { open(Sheet.Feedback) }
                SettingsRow("Give Us a Review", Icons.Filled.Star) {
                    url("https://play.google.com/store/apps/details?id=${context.packageName}")
                }
            }
            Section("LEGAL") {
                SettingsRow("Terms of Service", Icons.Filled.Description) { url("https://pushcraft.app/terms") }
                SettingsRow("Privacy Policy", Icons.Filled.PrivacyTip) { url("https://pushcraft.app/privacy-policy") }
            }
            Text("Version 1.0.0", style = rounded(12, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.6f), modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 6.dp))
        }
    }
    dialog?.let { (t, m) ->
        AlertDialog(
            onDismissRequest = { dialog = null }, containerColor = Pc.towersNavy,
            title = { Text(t, color = Pc.ivory) }, text = { Text(m, color = Pc.mist) },
            confirmButton = { TextButton({ dialog = null }) { Text("OK", color = Pc.amberSoft) } }
        )
    }
}

@Composable
private fun Section(title: String, rows: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = rounded(11, FontWeight.Bold, 1.8f), color = Pc.mist.copy(alpha = 0.8f), modifier = Modifier.padding(start = 4.dp))
        Column(Modifier.fillMaxWidth().battleCard()) { rows() }
    }
}

@Composable
private fun SettingsRow(title: String, icon: ImageVector, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().pressScale(onClick = onClick).padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(32.dp).background(Color.White.copy(alpha = 0.07f), RoundedCornerShape(9.dp)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Pc.iconBlue, modifier = Modifier.size(17.dp))
        }
        Text(title, style = rounded(16, FontWeight.SemiBold), color = Pc.ivory, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Pc.mist.copy(alpha = 0.7f), modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun EditProfileSheet(appState: AppState, onClose: () -> Unit) {
    val dashboard by appState.progress.dashboard.collectAsState()
    val current by appState.progress.avatar.collectAsState()
    val context = LocalContext.current
    var name by remember { mutableStateOf(dashboard?.profile?.displayName.orEmpty()) }
    var photo by remember { mutableStateOf(current) }
    var changed by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        context.contentResolver.openInputStream(uri)?.use { photo = it.readBytes(); changed = true }
    }
    val trimmed = name.trim()
    val canSave = trimmed.isNotEmpty() && trimmed.length <= 40 && !saving

    Column(Modifier.fillMaxSize()) {
        SheetHeader("Edit Profile", onClose)
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(20.dp).padding(bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Avatar(photo, 116.dp)
            Box(
                Modifier.height(40.dp).background(Color.White.copy(alpha = 0.08f), CircleShape).border(1.dp, Color.White.copy(alpha = 0.16f), CircleShape)
                    .pressScale { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }.padding(horizontal = 18.dp),
                contentAlignment = Alignment.Center
            ) { Text("Change Photo", style = rounded(15, FontWeight.Bold), color = Pc.ivory) }
            if (photo != null) Text("Remove Photo", style = rounded(14, FontWeight.SemiBold), color = Pc.mist, modifier = Modifier.pressScale { photo = null; changed = true })
            Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                SectionLabel("NAME")
                Box(Modifier.fillMaxWidth().height(50.dp).recessed().padding(horizontal = 14.dp), contentAlignment = Alignment.CenterStart) {
                    if (name.isEmpty()) Text("Your name", style = rounded(17, FontWeight.SemiBold), color = Pc.mist.copy(alpha = 0.5f))
                    BasicTextField(name, { name = it }, singleLine = true, textStyle = rounded(17, FontWeight.SemiBold).copy(color = Pc.ivory), cursorBrush = SolidColor(Pc.amberSoft), modifier = Modifier.fillMaxWidth())
                }
            }
            Text("Battle opponents can see your name and photo.", style = rounded(12, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.8f), modifier = Modifier.fillMaxWidth())
            error?.let { Text(it, style = rounded(13, FontWeight.SemiBold), color = Color(0xFFFF8A8A), modifier = Modifier.fillMaxWidth()) }
            GoldButton("Save Changes", isLoading = saving, enabled = canSave, icon = { Icon(Icons.Filled.Check, null, tint = Pc.buttonInk, modifier = Modifier.size(17.dp)) }) {
                saving = true; error = null
                scope.launch {
                    try {
                        appState.progress.updateProfile(trimmed, photo, changed)
                        onClose()
                    } catch (e: Exception) {
                        error = if (BackendFailure.isOffline(e)) "You're offline. Connect to save your changes." else "Couldn't save your profile. Please try again."
                    } finally { saving = false }
                }
            }
            Box(Modifier.fillMaxWidth().height(44.dp).pressScale(onClick = onClose), contentAlignment = Alignment.Center) {
                Text("Cancel", style = rounded(16, FontWeight.SemiBold), color = Pc.mist)
            }
        }
    }
}

@Composable
private fun AccountSheet(appState: AppState, onClose: () -> Unit) {
    val email by appState.email.collectAsState()
    val pending by appState.workouts.pending.collectAsState()
    val unsynced = appState.workouts.unsyncedCount(pending)
    var confirmOut by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxSize()) {
        SheetHeader("Account", onClose)
        Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Row(Modifier.fillMaxWidth().battleCard().padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(32.dp).background(Color.White.copy(alpha = 0.07f), RoundedCornerShape(9.dp)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Email, null, tint = Pc.iconBlue, modifier = Modifier.size(17.dp))
                }
                Column(Modifier.weight(1f)) {
                    Text("EMAIL", style = rounded(10, FontWeight.Bold, 1.6f), color = Pc.mist)
                    Text(email ?: "Hidden by your sign-in provider", style = rounded(16, FontWeight.SemiBold), color = Pc.ivory, maxLines = 1)
                }
                Icon(Icons.Filled.Lock, null, tint = Pc.mist.copy(alpha = 0.6f), modifier = Modifier.size(14.dp))
            }
            GoldButton("Sign Out", icon = { Icon(Icons.AutoMirrored.Filled.Logout, null, tint = Pc.buttonInk, modifier = Modifier.size(17.dp)) }) { confirmOut = true }
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("DANGER ZONE", style = rounded(11, FontWeight.Bold, 1.8f), color = Pc.danger, modifier = Modifier.padding(start = 4.dp))
                Column(
                    Modifier.fillMaxWidth().background(Pc.danger.copy(alpha = 0.08f), RoundedCornerShape(22.dp)).border(1.dp, Pc.danger.copy(alpha = 0.45f), RoundedCornerShape(22.dp)).padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text("Deleting your account is permanent. All progress will be lost.", style = rounded(13, FontWeight.Medium), color = Pc.mist)
                    Box(
                        Modifier.fillMaxWidth().height(50.dp).shadow(10.dp, RoundedCornerShape(14.dp), ambientColor = Color(0xFFE04848), spotColor = Color(0xFFE04848))
                            .background(Brush.verticalGradient(listOf(Color(0xFFFF7B7B), Color(0xFFE04848))), RoundedCornerShape(14.dp))
                            .pressScale(!deleting) { confirmDelete = true },
                        contentAlignment = Alignment.Center
                    ) { Text(if (deleting) "Deleting…" else "Delete Account", style = rounded(17, FontWeight.Bold), color = Color.White) }
                }
            }
        }
    }
    if (confirmOut) {
        AlertDialog(
            onDismissRequest = { confirmOut = false }, containerColor = Pc.towersNavy,
            title = { Text("Sign out of Pushcraft?", color = Pc.ivory, style = rounded(19, FontWeight.Bold)) },
            text = {
                Text(
                    if (unsynced > 0) "$unsynced workout${if (unsynced == 1) " hasn't" else "s haven't"} synced yet. They stay on this phone and sync next time you sign in to this account."
                    else "Your progress is saved to your account.", color = Pc.mist
                )
            },
            confirmButton = { TextButton({ confirmOut = false; scope.launch { appState.signOut() } }) { Text("Sign Out", color = Pc.danger) } },
            dismissButton = { TextButton({ confirmOut = false }) { Text("Cancel", color = Pc.amberSoft) } }
        )
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false }, containerColor = Pc.towersNavy,
            title = { Text("Delete account?", color = Pc.ivory, style = rounded(19, FontWeight.Bold)) },
            text = {
                Text(
                    "This permanently deletes your profile, photo, workouts, towers and stats. Past battles stay for your opponents as \"Deleted player\". This doesn't cancel a Google Play subscription — manage that in the Play Store.",
                    color = Pc.mist
                )
            },
            confirmButton = {
                TextButton({
                    confirmDelete = false; deleting = true
                    scope.launch {
                        try { appState.deleteAccount() } catch (e: Exception) {
                            error = if (BackendFailure.isOffline(e)) "You're offline. Connect to the internet and try again." else "Something went wrong. Please try again."
                        } finally { deleting = false }
                    }
                }) { Text("Delete Account", color = Pc.danger) }
            },
            dismissButton = { TextButton({ confirmDelete = false }) { Text("Cancel", color = Pc.amberSoft) } }
        )
    }
    error?.let { msg ->
        AlertDialog(
            onDismissRequest = { error = null }, containerColor = Pc.towersNavy,
            title = { Text("Couldn't delete account", color = Pc.ivory) }, text = { Text(msg, color = Pc.mist) },
            confirmButton = { TextButton({ error = null }) { Text("OK", color = Pc.amberSoft) } }
        )
    }
}

@Composable
private fun SubscriptionSheet(appState: AppState, onClose: () -> Unit) {
    val state by appState.store.state.collectAsState()
    val context = LocalContext.current
    val id = state.activeProductId.orEmpty()
    val plan = when {
        "year" in id || "annual" in id -> "Pushcraft Yearly"
        "week" in id -> "Pushcraft Weekly"
        else -> "Pushcraft Premium"
    }
    val status = if (state.access != StoreService.Access.Premium) "No active subscription"
    else state.expiration?.let { (if (state.willRenew) "Active · Renews " else "Active · Ends ") + formatDate(it) } ?: "Active"
    Column(Modifier.fillMaxSize()) {
        SheetHeader("Subscription", onClose)
        Column(Modifier.padding(20.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Row(
                Modifier.fillMaxWidth().shadow(10.dp, RoundedCornerShape(22.dp)).background(Pc.battleCard, RoundedCornerShape(22.dp))
                    .border(1.dp, Pc.gold.copy(alpha = 0.45f), RoundedCornerShape(22.dp)).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Box(
                    Modifier.size(48.dp).background(Pc.gold.copy(alpha = 0.12f), RoundedCornerShape(14.dp)).border(1.dp, Pc.gold.copy(alpha = 0.4f), RoundedCornerShape(14.dp)),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Filled.WorkspacePremium, null, tint = Pc.gold, modifier = Modifier.size(26.dp)) }
                Column {
                    Text(plan, style = rounded(18, FontWeight.Bold), color = Pc.ivory)
                    Text(status, style = rounded(13, FontWeight.Medium), color = Pc.mist)
                }
            }
            GoldButton("Manage Subscription", icon = { Icon(Icons.AutoMirrored.Filled.OpenInNew, null, tint = Pc.buttonInk, modifier = Modifier.size(17.dp)) }) {
                runCatching {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/account/subscriptions?package=${context.packageName}")))
                }
            }
            Text(
                "Manage Subscription opens Google Play's Subscriptions page, where you can change or cancel your plan.",
                style = rounded(13, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.8f)
            )
        }
    }
}

@Composable
private fun ToggleSheet(
    title: String, icon: ImageVector, description: String,
    flow: kotlinx.coroutines.flow.StateFlow<Boolean>, onToggle: (Boolean) -> Unit, onClose: () -> Unit
) {
    val on by flow.collectAsState()
    val context = LocalContext.current
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { onToggle(it) }
    Column(Modifier.fillMaxWidth()) {
        SheetHeader(title, onClose)
        Column(Modifier.padding(20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Row(Modifier.fillMaxWidth().battleCard().padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(Modifier.size(44.dp).background(Color.White.copy(alpha = 0.07f), RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                    Icon(icon, null, tint = Pc.iconBlue, modifier = Modifier.size(20.dp))
                }
                Text(description, style = rounded(14, FontWeight.Medium), color = Pc.mist)
            }
            Row(Modifier.fillMaxWidth().battleCard().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Enable $title", style = rounded(16, FontWeight.SemiBold), color = Pc.ivory, modifier = Modifier.weight(1f))
                Switch(
                    on,
                    { v ->
                        if (v && title == "Notifications" && !Reminders.hasPermission(context) && android.os.Build.VERSION.SDK_INT >= 33) {
                            launcher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                        } else onToggle(v)
                    },
                    colors = SwitchDefaults.colors(checkedTrackColor = Pc.amber, checkedThumbColor = Color.White)
                )
            }
        }
    }
}

@Composable
private fun FeedbackSheet(onClose: () -> Unit) {
    val categories = listOf("Feature Request", "Bug Request", "General")
    var category by remember { mutableStateOf<String?>(null) }
    var message by remember { mutableStateOf("") }
    var submitted by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val canSubmit = category != null && message.isNotBlank()
    Column(Modifier.fillMaxSize()) {
        SheetHeader("Provide Feedback", onClose)
        Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SectionLabel("CATEGORY")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    categories.forEach { c ->
                        val sel = category == c
                        Box(
                            Modifier.weight(1f).height(36.dp).background(if (sel) AmberGradient else SolidColor(Color.White.copy(alpha = 0.06f)), CircleShape)
                                .border(1.dp, Color.White.copy(alpha = if (sel) 0f else 0.14f), CircleShape)
                                .pressScale { category = if (sel) null else c },
                            contentAlignment = Alignment.Center
                        ) { Text(c, style = rounded(13, FontWeight.Bold), color = if (sel) Pc.buttonInk else Pc.mist, maxLines = 1) }
                    }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SectionLabel("MESSAGE")
                Box(Modifier.fillMaxWidth().heightIn(min = 150.dp).recessed().padding(14.dp)) {
                    if (message.isEmpty()) Text("Tell us what's on your mind…", style = rounded(16, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.5f))
                    BasicTextField(message, { message = it }, textStyle = rounded(16, FontWeight.Medium).copy(color = Pc.ivory), cursorBrush = SolidColor(Pc.amberSoft), modifier = Modifier.fillMaxWidth())
                }
            }
            if (submitted) {
                Row(Modifier.fillMaxWidth().padding(vertical = 14.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.CheckCircle, null, tint = Pc.success, modifier = Modifier.size(24.dp))
                    Spacer(Modifier.width(10.dp))
                    Text("Thanks for your feedback!", style = rounded(16, FontWeight.Bold), color = Pc.ivory)
                }
            } else {
                GoldButton("Submit Feedback", enabled = canSubmit, icon = { Icon(Icons.AutoMirrored.Filled.Send, null, tint = Pc.buttonInk, modifier = Modifier.size(16.dp)) }) {
                    submitted = true; message = ""; category = null
                    scope.launch { delay(1400); onClose() }
                }
            }
        }
    }
}
