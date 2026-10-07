import SwiftUI
import UIKit

// MARK: - Account

/// Account bottom sheet: read-only email, Sign Out (warns about unsynced
/// workouts), and a Danger Zone with permanent account deletion.
struct AccountSheet: View {
    @Environment(AppState.self) private var appState

    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var unsynced: Int { appState.workouts.unsyncedCount }

    var body: some View {
        SheetScaffold(title: "Account", detents: [.medium, .large]) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xAFC3E8))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.07), in: .rect(cornerRadius: 9, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("EMAIL")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.6)
                                .foregroundStyle(Theme.mist)
                            Text(appState.email ?? "Hidden by your sign-in provider")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.ivory)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.mist.opacity(0.6))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .battleCardStyle()

                    GoldButton(title: "Sign Out") {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    } action: {
                        confirmSignOut = true
                    }

                    dangerZone
                }
                .padding(20)
                .padding(.bottom, 24)
            }
        }
        .confirmationDialog(
            "Sign out of Pushcraft?",
            isPresented: $confirmSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task { await appState.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(unsynced > 0
                 ? "\(unsynced) workout\(unsynced == 1 ? " hasn't" : "s haven't") synced yet. They stay on this phone and sync next time you sign in to this account."
                 : "Your progress is saved to your account.")
        }
        .confirmationDialog(
            "Delete account?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your profile, photo, workouts, towers and stats. Past battles stay for your opponents as \"Deleted player\". This doesn't cancel an Apple subscription — manage that in Settings.")
        }
        .alert(
            "Couldn't delete account",
            isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
        ) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await appState.deleteAccount()
            } catch {
                deleteError = BackendFailure.isOffline(error)
                    ? "You're offline. Connect to the internet and try again."
                    : "Something went wrong. Please try again."
            }
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DANGER ZONE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(Color(hex: 0xFF6B6B))
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 12) {
                Text("Deleting your account is permanent. All progress will be lost.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mist)

                Button {
                    confirmDelete = true
                } label: {
                    Text(isDeleting ? "Deleting…" : "Delete Account")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            .linearGradient(
                                colors: [Color(hex: 0xFF7B7B), Color(hex: 0xE04848)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: .rect(cornerRadius: 14, style: .continuous)
                        )
                        .shadow(color: Color(hex: 0xE04848).opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(PressScaleStyle())
                .disabled(isDeleting)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(hex: 0xFF6B6B).opacity(0.08),
                in: .rect(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color(hex: 0xFF6B6B).opacity(0.45), lineWidth: 1)
            }
        }
    }
}

// MARK: - Subscription

/// Subscription bottom sheet showing the RevenueCat plan status and a button
/// that opens Apple's subscription management page.
struct SubscriptionSheet: View {
    @Environment(AppState.self) private var appState
    @State private var showUnavailableDialog = false

    private var planName: String {
        let id = appState.store.activeProductID ?? ""
        if id.contains("year") { return "Pushcraft Yearly" }
        if id.contains("week") { return "Pushcraft Weekly" }
        return "Pushcraft Premium"
    }

    private var statusText: String {
        guard appState.store.access == .premium else { return "No active subscription" }
        guard let date = appState.store.expirationDate else { return "Active" }
        let day = date.formatted(date: .abbreviated, time: .omitted)
        return appState.store.willRenew ? "Active · Renews \(day)" : "Active · Ends \(day)"
    }

    var body: some View {
        SheetScaffold(title: "Subscription", detents: [.medium, .large]) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    planCard

                    GoldButton(title: "Manage Subscription") {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 15, weight: .bold))
                    } action: {
                        manageSubscription()
                    }

                    Text("Manage Subscription opens Apple's Subscriptions page in the App Store, where you can change or cancel your plan.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist.opacity(0.8))
                }
                .padding(20)
                .padding(.bottom, 24)
            }
        }
        .alert("Not available here", isPresented: $showUnavailableDialog) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Subscription management isn't available in this preview. On a real device, this opens Apple's Subscriptions page in the App Store.")
        }
    }

    private var planCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 48, height: 48)
                .background(Theme.gold.opacity(0.12), in: .rect(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(planName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                Text(statusText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mist)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(hex: 0x121F3A),
            in: .rect(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }

    private func manageSubscription() {
        guard let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") else {
            showUnavailableDialog = true
            return
        }
        UIApplication.shared.open(url) { success in
            if !success { showUnavailableDialog = true }
        }
    }
}

// MARK: - Preference toggles

/// Generic single-toggle preference sheet (Notifications, Haptic, Sound
/// Effects). The selection is persisted on the device via AppPreferences.
struct PreferenceToggleSheet: View {
    let title: String
    let systemImage: String
    let description: String
    let keyPath: ReferenceWritableKeyPath<AppPreferences, Bool>
    var onChange: ((Bool) -> Void)? = nil

    private var prefs: AppPreferences { AppPreferences.shared }

    var body: some View {
        SheetScaffold(title: title, detents: [.medium]) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xAFC3E8))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.07), in: .rect(cornerRadius: 12, style: .continuous))

                        Text(description)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.mist)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .battleCardStyle()

                    HStack {
                        Text("Enable \(title)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ivory)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { prefs[keyPath: keyPath] },
                            set: {
                                prefs[keyPath: keyPath] = $0
                                onChange?($0)
                            }
                        ))
                        .tint(Theme.amber)
                        .labelsHidden()
                    }
                    .padding(16)
                    .battleCardStyle()
                }
                .padding(20)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Feedback

/// Provide Feedback bottom sheet: category selector, multiline message field,
/// and a simulated submission with a thank-you confirmation.
struct FeedbackSheet: View {
    private enum Category: String, CaseIterable, Identifiable {
        case feature = "Feature Request"
        case bug = "Bug Request"
        case general = "General"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var category: Category?
    @State private var message = ""
    @State private var submitted = false

    private var canSubmit: Bool {
        category != nil && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SheetScaffold(title: "Provide Feedback", detents: [.large]) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CATEGORY")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.6)
                            .foregroundStyle(Theme.mist)

                        HStack(spacing: 8) {
                            categoryChip(.feature)
                            categoryChip(.bug)
                            categoryChip(.general)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("MESSAGE")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.6)
                            .foregroundStyle(Theme.mist)

                        TextField(
                            "Tell us what's on your mind…",
                            text: $message,
                            axis: .vertical
                        )
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(6...12)
                        .padding(14)
                        .recessedFieldStyle()
                    }

                    if submitted {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color(hex: 0x3DDC84))
                            Text("Thanks for your feedback!")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.ivory)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        GoldButton(title: "Submit Feedback") {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 15, weight: .bold))
                        } action: {
                            submit()
                        }
                        .opacity(canSubmit ? 1 : 0.5)
                        .disabled(!canSubmit)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: submitted)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func categoryChip(_ chip: Category) -> some View {
        let isSelected = category == chip
        return Button {
            category = isSelected ? nil : chip
        } label: {
            Text(chip.rawValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Color(hex: 0x3A2200) : Theme.mist)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background {
                    if isSelected {
                        Capsule().fill(
                            .linearGradient(
                                colors: [Theme.amberSoft, Theme.amberDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    } else {
                        Capsule().fill(.white.opacity(0.06))
                    }
                }
                .overlay { Capsule().strokeBorder(.white.opacity(isSelected ? 0 : 0.14), lineWidth: 1) }
        }
        .buttonStyle(PressScaleStyle())
    }

    private func submit() {
        guard canSubmit else { return }
        // Simulated submission — nothing is sent to a real service.
        withAnimation { submitted = true }
        message = ""
        category = nil
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            dismiss()
        }
    }
}

#Preview {
    AccountSheet()
        .environment(AppState())
}
