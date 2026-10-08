import RevenueCat
import SwiftUI

/// Hard paywall. Shown to every signed-in user without an active
/// subscription; access unlocks only after a successful purchase or restore.
struct PaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    private enum Plan { case weekly, yearly }

    @State private var plan: Plan = .weekly
    @State private var alert: PaywallAlert?
    @State private var hasAppeared = false

    private var store: StoreService { appState.store }
    private var intro: StoreProductDiscount? { store.weeklyIntro }
    private var weeklyPrice: String { store.weekly?.storeProduct.localizedPriceString ?? "—" }
    private var yearlyPrice: String { store.yearly?.storeProduct.localizedPriceString ?? "—" }
    private var selectedPackage: Package? { plan == .weekly ? store.weekly : store.yearly }
    private var isBusy: Bool { store.isPurchasing || store.isRestoring }

    private let features: [(String, String, String)] = [
        ("paywall_swords", "Compete in Battles", "Challenge other players and test your strength."),
        ("paywall_tower", "Build Your Tower", "Break blocks with push-ups and watch your tower rise."),
        ("paywall_dumbbell", "Customized Workout Plan", "Workouts tailored to your fitness level."),
        ("paywall_ai_push", "AI Push-Up Tracking", "Reps counted automatically.")
    ]

    var body: some View {
        ZStack {
            Theme.paywallBg.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: 0x1C3463, opacity: 0.55), .clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heading
                        .padding(.top, 28)

                    featureList
                        .padding(.top, 26)

                    VStack(spacing: 14) {
                        weeklyCard
                        yearlyCard
                    }
                    .padding(.top, 26)

                    if let error = store.offeringsError {
                        Button {
                            HapticService.ui.tap()
                            Task { await store.loadOfferings() }
                        } label: {
                            Label(error + " Tap to retry.", systemImage: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.amberSoft)
                                .multilineTextAlignment(.center)
                                .frame(minHeight: 44)
                        }
                        .padding(.top, 6)
                    }

                    continueButton
                        .padding(.top, 20)

                    explanation
                        .padding(.top, 12)

                    footer
                        .padding(.top, 14)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 22)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .preferredColorScheme(.dark)
        .task {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { hasAppeared = true }
            AnalyticsService.trackPaywallViewed(
                hasIntroOffer: intro != nil,
                weeklyPrice: store.weekly?.storeProduct.localizedPriceString,
                yearlyPrice: store.yearly?.storeProduct.localizedPriceString
            )
            if store.weekly == nil && store.yearly == nil && !store.isLoadingOfferings {
                await store.loadOfferings()
            }
        }
        .alert(item: $alert) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Heading & features

    private var heading: some View {
        VStack(spacing: 2) {
            Text("Get Stronger with")
                .foregroundStyle(.white)
            Text("PushcraftPushUpFitnessGame")
                .foregroundStyle(Theme.paywallGold)
        }
        .font(.system(size: 36, weight: .heavy, design: .rounded))
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                HStack(alignment: .top, spacing: 16) {
                    Image(feature.0)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.1)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(feature.2)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.mist)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12)

                if index < features.count - 1 {
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.leading, 66)
                }
            }
        }
    }

    // MARK: - Plans

    private var weeklyCard: some View {
        PlanCard(isSelected: plan == .weekly, badge: intro != nil ? "FIRST WEEK OFFER" : nil) {
            select(.weekly)
        } leading: {
            Text("Weekly")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(intro != nil ? "Then \(weeklyPrice)/week" : "Billed weekly")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
        } trailing: {
            if let intro {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(intro.localizedPriceString)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(StoreService.introPeriodText(intro))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist)
                }
            } else {
                Text("\(weeklyPrice)/week")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private var yearlyCard: some View {
        PlanCard(isSelected: plan == .yearly, badge: nil) {
            select(.yearly)
        } leading: {
            Text("Yearly")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Billed annually")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
        } trailing: {
            Text("\(yearlyPrice)/year")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func select(_ newPlan: Plan) {
        guard plan != newPlan else { return }
        HapticService.ui.selection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { plan = newPlan }
    }

    // MARK: - Purchase

    private var continueTitle: String {
        plan == .weekly && intro != nil ? "Claim my first week" : "Continue"
    }

    private var continueButton: some View {
        Button {
            HapticService.ui.tap()
            Task { await purchase() }
        } label: {
            ZStack {
                if store.isPurchasing {
                    ProgressView().tint(Theme.paywallInk)
                } else {
                    Text(continueTitle)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.paywallInk)
                        .contentTransition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.paywallGoldEdge)
                        .offset(y: 5)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.linearGradient(colors: [Theme.paywallGold, Theme.paywallGoldDeep], startPoint: .top, endPoint: .bottom))
                }
            }
            .shadow(color: Theme.paywallGold.opacity(0.3), radius: 14, y: 6)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(selectedPackage == nil || isBusy)
        .opacity(selectedPackage == nil ? 0.5 : 1)
        .animation(.easeOut(duration: 0.2), value: continueTitle)
    }

    private var explanation: some View {
        VStack(spacing: 3) {
            Text(planSummary)
            Text("No commitment. Cancel anytime.")
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(Theme.mist.opacity(0.85))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: plan)
    }

    private var planSummary: String {
        switch plan {
        case .weekly:
            if let intro {
                return "\(intro.localizedPriceString) for your \(StoreService.introPeriodText(intro)), then \(weeklyPrice)/week."
            }
            return "\(weeklyPrice)/week, billed weekly."
        case .yearly:
            return "\(yearlyPrice)/year, billed annually."
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Restore Purchases") {
                HapticService.ui.tap()
                Task { await restore() }
            }
            .disabled(isBusy)
            Text("·").accessibilityHidden(true)
            Button("Terms") {
                HapticService.ui.tap()
                if let url = URL(string: "https://www.pushcraft.app/terms") { openURL(url) }
            }
            Text("·").accessibilityHidden(true)
            Button("Privacy") {
                HapticService.ui.tap()
                if let url = URL(string: "https://www.pushcraft.app/privacy-policy") { openURL(url) }
            }
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(Theme.mist)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .overlay {
            if store.isRestoring {
                ProgressView().tint(Theme.paywallGold)
            }
        }
    }

    private func purchase() async {
        guard let package = selectedPackage else { return }
        let planName = plan == .weekly ? "weekly" : "yearly"
        let hasIntroOffer = plan == .weekly && intro != nil
        AnalyticsService.trackPurchaseStarted(
            plan: planName,
            productID: package.storeProduct.productIdentifier,
            hasIntroOffer: hasIntroOffer
        )
        switch await store.purchase(package) {
        case .success:
            HapticService.ui.success()
            AnalyticsService.trackSubscriptionStarted(
                plan: planName,
                productID: package.storeProduct.productIdentifier,
                hasIntroOffer: hasIntroOffer
            )
        case .cancelled:
            AnalyticsService.trackPurchaseCancelled(plan: planName)
        case .pending:
            AnalyticsService.trackPurchasePending(plan: planName)
            alert = PaywallAlert(title: "Purchase pending", message: "Your purchase is waiting for approval. PushcraftPushUpFitnessGame unlocks as soon as it goes through.")
        case .failed(let message):
            HapticService.ui.warning()
            AnalyticsService.trackPurchaseFailed(plan: planName)
            alert = PaywallAlert(title: "Purchase didn't complete", message: message)
        }
    }

    private func restore() async {
        switch await store.restore() {
        case .restored:
            HapticService.ui.success()
            AnalyticsService.trackPurchaseRestored()
        case .nothingFound:
            alert = PaywallAlert(title: "Nothing to restore", message: "We couldn't find an active PushcraftPushUpFitnessGame subscription for this Apple ID.")
        case .failed(let message):
            alert = PaywallAlert(title: "Restore failed", message: message)
        }
    }
}

private struct PaywallAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Selectable plan card. The whole card is the tap target.
private struct PlanCard<Leading: View, Trailing: View>: View {
    let isSelected: Bool
    let badge: String?
    let action: () -> Void
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Theme.paywallGold : Theme.paywallSlate, lineWidth: 2)
                        .frame(width: 28, height: 28)
                    if isSelected {
                        Circle()
                            .fill(Theme.paywallGold)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.paywallInk)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    leading()
                }
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(minHeight: 84)
            .background(Color(hex: 0x0F2040), in: .rect(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Theme.paywallGold : Theme.paywallSlate, lineWidth: isSelected ? 2.5 : 1.5)
            }
            .shadow(color: isSelected ? Theme.paywallGold.opacity(0.35) : .clear, radius: 14)
            .overlay(alignment: .top) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(Theme.paywallInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Theme.paywallGold, in: .capsule)
                        .offset(y: -12)
                }
            }
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
