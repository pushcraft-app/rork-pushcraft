import Foundation
import Observation
import RevenueCat

/// Subscription state from RevenueCat. Access is only decided after the
/// RevenueCat user is linked to the Supabase account, so subscribers never
/// see the paywall flash while their status loads.
@Observable
final class StoreService {
    enum Access: Equatable {
        case unknown, premium, none
    }

    enum PurchaseOutcome: Equatable {
        case success, cancelled, pending
        case failed(String)
    }

    enum RestoreOutcome: Equatable {
        case restored, nothingFound
        case failed(String)
    }

    static let entitlementID = "premium"

    private(set) var access: Access = .unknown
    private(set) var weekly: Package?
    private(set) var yearly: Package?
    /// The paid introductory offer for the weekly plan, only when eligible.
    private(set) var weeklyIntro: StoreProductDiscount?
    private(set) var isLoadingOfferings = false
    private(set) var offeringsError: String?
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var activeProductID: String?
    private(set) var expirationDate: Date?
    private(set) var willRenew = false

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var linkedUserID: String?
    @ObservationIgnored private var pendingUserID: UUID?

    func start() {
        guard streamTask == nil, Purchases.isConfigured else { return }
        streamTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard let self else { return }
                if let linked = self.linkedUserID, Purchases.shared.appUserID == linked {
                    self.apply(info)
                }
            }
        }
    }

    // MARK: - Account linking

    func logIn(userID: UUID) async {
        guard Purchases.isConfigured else {
            access = .none
            return
        }
        pendingUserID = userID
        let id = userID.uuidString.lowercased()
        do {
            let result = try await Purchases.shared.logIn(id)
            linkedUserID = id
            pendingUserID = nil
            apply(result.customerInfo)
            print("[Store] Linked subscriber; premium=\(access == .premium)")
        } catch {
            print("[Store] logIn failed: \(error.localizedDescription)")
            access = .none
        }
        await loadOfferings()
    }

    func logOut() async {
        linkedUserID = nil
        pendingUserID = nil
        access = .unknown
        activeProductID = nil
        expirationDate = nil
        guard Purchases.isConfigured, !Purchases.shared.isAnonymous else { return }
        _ = try? await Purchases.shared.logOut()
    }

    /// Foreground refresh: retries linking, re-reads status, reloads plans if missing.
    func refresh() async {
        if let pending = pendingUserID, linkedUserID == nil {
            await logIn(userID: pending)
            return
        }
        guard linkedUserID != nil else { return }
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }
        if weekly == nil && yearly == nil {
            await loadOfferings()
        }
    }

    // MARK: - Plans

    func loadOfferings() async {
        guard Purchases.isConfigured else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            let current = offerings.current
            let packages = current?.availablePackages ?? []
            weekly = current?.weekly ?? packages.first { $0.storeProduct.subscriptionPeriod?.unit == .week }
            yearly = current?.annual ?? packages.first { $0.storeProduct.subscriptionPeriod?.unit == .year }
            offeringsError = (weekly == nil && yearly == nil) ? "Plans aren't available right now." : nil
            await updateIntroEligibility()
        } catch {
            print("[Store] Offerings failed: \(error.localizedDescription)")
            offeringsError = "Couldn't load plans. Check your connection and try again."
        }
    }

    private func updateIntroEligibility() async {
        weeklyIntro = nil
        guard
            let product = weekly?.storeProduct,
            let intro = product.introductoryDiscount,
            intro.paymentMode != .freeTrial
        else { return }
        let status = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product)
        if status == .eligible {
            weeklyIntro = intro
        }
    }

    // MARK: - Purchasing

    func purchase(_ package: Package) async -> PurchaseOutcome {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            apply(result.customerInfo)
            return access == .premium
                ? .success
                : .failed("Your purchase went through, but access hasn't unlocked yet. Try Restore Purchases.")
        } catch ErrorCode.purchaseCancelledError {
            return .cancelled
        } catch ErrorCode.paymentPendingError {
            return .pending
        } catch {
            print("[Store] Purchase failed: \(error.localizedDescription)")
            return .failed("The payment didn't complete. You haven't been charged. Please try again.")
        }
    }

    func restore() async -> RestoreOutcome {
        isRestoring = true
        defer { isRestoring = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return access == .premium ? .restored : .nothingFound
        } catch {
            print("[Store] Restore failed: \(error.localizedDescription)")
            return .failed("Couldn't restore purchases. Check your connection and try again.")
        }
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[Self.entitlementID]
        access = entitlement?.isActive == true ? .premium : .none
        activeProductID = entitlement?.productIdentifier
        expirationDate = entitlement?.expirationDate
        willRenew = entitlement?.willRenew ?? false
    }

    /// "first week", "first 2 weeks", "first month"…
    static func introPeriodText(_ discount: StoreProductDiscount?) -> String {
        guard let discount else { return "first week" }
        let total = discount.subscriptionPeriod.value * discount.numberOfPeriods
        let unit: String
        switch discount.subscriptionPeriod.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        default: unit = "year"
        }
        return total == 1 ? "first \(unit)" : "first \(total) \(unit)s"
    }
}
