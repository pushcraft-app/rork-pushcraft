package com.rork.pushcraftandroid.data

import android.app.Activity
import android.util.Log
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitLogIn
import com.revenuecat.purchases.awaitLogOut
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Instant

/** Subscription state from RevenueCat, linked to the Supabase account. */
class StoreService {
    enum class Access { Unknown, Premium, None }

    sealed interface PurchaseOutcome {
        data object Success : PurchaseOutcome
        data object Cancelled : PurchaseOutcome
        data class Failed(val message: String) : PurchaseOutcome
    }

    sealed interface RestoreOutcome {
        data object Restored : RestoreOutcome
        data object NothingFound : RestoreOutcome
        data class Failed(val message: String) : RestoreOutcome
    }

    data class State(
        val access: Access = Access.Unknown,
        val weekly: Package? = null,
        val yearly: Package? = null,
        val isLoadingOfferings: Boolean = false,
        val offeringsError: String? = null,
        val isPurchasing: Boolean = false,
        val isRestoring: Boolean = false,
        val activeProductId: String? = null,
        val expiration: Instant? = null,
        val willRenew: Boolean = false
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    private var linkedUserId: String? = null
    private var pendingUserId: String? = null

    fun start() {
        if (!Purchases.isConfigured) return
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { info ->
            val linked = linkedUserId
            if (linked != null && Purchases.sharedInstance.appUserID == linked) apply(info)
        }
    }

    suspend fun logIn(userId: String) {
        if (!Purchases.isConfigured) {
            _state.value = _state.value.copy(access = Access.None)
            return
        }
        pendingUserId = userId
        val id = userId.lowercase()
        try {
            val result = Purchases.sharedInstance.awaitLogIn(id)
            linkedUserId = id
            pendingUserId = null
            apply(result.customerInfo)
        } catch (e: Exception) {
            Log.w("Store", "logIn failed: ${e.message}")
            _state.value = _state.value.copy(access = Access.None)
        }
        loadOfferings()
    }

    suspend fun logOut() {
        linkedUserId = null
        pendingUserId = null
        _state.value = _state.value.copy(access = Access.Unknown, activeProductId = null, expiration = null)
        if (!Purchases.isConfigured || Purchases.sharedInstance.isAnonymous) return
        runCatching { Purchases.sharedInstance.awaitLogOut() }
    }

    suspend fun refresh() {
        val pending = pendingUserId
        if (pending != null && linkedUserId == null) {
            logIn(pending)
            return
        }
        if (linkedUserId == null) return
        runCatching { Purchases.sharedInstance.awaitCustomerInfo() }.getOrNull()?.let { apply(it) }
        if (_state.value.weekly == null && _state.value.yearly == null) loadOfferings()
    }

    suspend fun loadOfferings() {
        if (!Purchases.isConfigured) return
        _state.value = _state.value.copy(isLoadingOfferings = true)
        try {
            val current = Purchases.sharedInstance.awaitOfferings().current
            val packages = current?.availablePackages.orEmpty()
            val weekly = current?.weekly ?: packages.firstOrNull { it.product.period?.unit?.name == "WEEK" }
            val yearly = current?.annual ?: packages.firstOrNull { it.product.period?.unit?.name == "YEAR" }
            _state.value = _state.value.copy(
                weekly = weekly,
                yearly = yearly,
                offeringsError = if (weekly == null && yearly == null) "Plans aren't available right now." else null
            )
        } catch (e: Exception) {
            Log.w("Store", "Offerings failed: ${e.message}")
            _state.value = _state.value.copy(offeringsError = "Couldn't load plans. Check your connection and try again.")
        } finally {
            _state.value = _state.value.copy(isLoadingOfferings = false)
        }
    }

    suspend fun purchase(activity: Activity, pkg: Package): PurchaseOutcome {
        _state.value = _state.value.copy(isPurchasing = true)
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, pkg).build())
            apply(result.customerInfo)
            if (_state.value.access == Access.Premium) PurchaseOutcome.Success
            else PurchaseOutcome.Failed("Your purchase went through, but access hasn't unlocked yet. Try Restore Purchases.")
        } catch (e: PurchasesTransactionException) {
            if (e.userCancelled) PurchaseOutcome.Cancelled
            else PurchaseOutcome.Failed("The payment didn't complete. You haven't been charged. Please try again.")
        } catch (e: PurchasesException) {
            PurchaseOutcome.Failed("The payment didn't complete. You haven't been charged. Please try again.")
        } finally {
            _state.value = _state.value.copy(isPurchasing = false)
        }
    }

    suspend fun restore(): RestoreOutcome {
        _state.value = _state.value.copy(isRestoring = true)
        return try {
            apply(Purchases.sharedInstance.awaitRestore())
            if (_state.value.access == Access.Premium) RestoreOutcome.Restored else RestoreOutcome.NothingFound
        } catch (e: Exception) {
            RestoreOutcome.Failed("Couldn't restore purchases. Check your connection and try again.")
        } finally {
            _state.value = _state.value.copy(isRestoring = false)
        }
    }

    private fun apply(info: CustomerInfo) {
        val ent = info.entitlements[ENTITLEMENT]
        _state.value = _state.value.copy(
            access = if (ent?.isActive == true) Access.Premium else Access.None,
            activeProductId = ent?.productIdentifier,
            expiration = ent?.expirationDate?.toInstant(),
            willRenew = ent?.willRenew ?: false
        )
    }

    companion object {
        const val ENTITLEMENT = "premium"
    }
}
