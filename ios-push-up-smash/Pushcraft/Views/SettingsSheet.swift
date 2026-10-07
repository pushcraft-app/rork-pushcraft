import SwiftUI
import UIKit

/// Settings bottom sheet opened from the Profile page. Child screens open as
/// additional sheets stacked above this one; closing them returns here.
struct SettingsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var child: SettingsChild?
    @State private var showReviewDialog = false
    @State private var showMailDialog = false

    /// App Store app ID for review links. Until a real ID is provided, the
    /// review row shows a prototype message instead of linking to another app.
    private let appStoreAppID: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .frame(maxWidth: .infinity)

            HStack {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.mist)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.08), in: .circle)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Close settings")
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    section("ACCOUNT") {
                        SettingsRow(title: "Account", systemImage: "person.crop.circle") { child = .account }
                        SettingsRow(title: "Subscription", systemImage: "star.circle") { child = .subscription }
                    }

                    section("PREFERENCES") {
                        SettingsRow(title: "Notifications", systemImage: "bell") { child = .notifications }
                        SettingsRow(title: "Haptic", systemImage: "hand.tap.fill") { child = .haptics }
                        SettingsRow(title: "Sound Effects", systemImage: "speaker.wave.2.fill") { child = .sound }
                    }

                    section("SUPPORT") {
                        SettingsRow(title: "Contact Support", systemImage: "envelope") { contactSupport() }
                    }

                    section("FEEDBACK") {
                        SettingsRow(title: "Provide Feedback", systemImage: "bubble.left.and.text.bubble.right") { child = .feedback }
                        SettingsRow(title: "Give Us a Review", systemImage: "star.fill") { openReview() }
                    }

                    section("LEGAL") {
                        SettingsRow(title: "Terms of Service", systemImage: "doc.text") { openURL("https://pushcraft.app/terms") }
                        SettingsRow(title: "Privacy Policy", systemImage: "lock.shield") { openURL("https://pushcraft.app/privacy-policy") }
                    }

                    Text("Version 1.0.0")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Theme.night.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .sheet(item: $child) { child in
            childView(child)
        }
        .alert("Give Us a Review", isPresented: $showReviewDialog) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This opens our App Store review page once Pushcraft is published. The App Store app ID isn't configured yet in this prototype.")
        }
        .alert("Contact Support", isPresented: $showMailDialog) {
            Button("Copy Email") {
                UIPasteboard.general.string = "contact@pushcraft.app"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("No email app is available. Reach us at contact@pushcraft.app.")
        }
    }

    // MARK: - Sections & rows

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder rows: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(Theme.mist.opacity(0.8))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                rows()
            }
            .battleCardStyle()
        }
    }

    // MARK: - Child sheets

    @ViewBuilder
    private func childView(_ child: SettingsChild) -> some View {
        switch child {
        case .account:
            AccountSheet()
                .environment(appState)
        case .subscription:
            SubscriptionSheet()
                .environment(appState)
        case .notifications:
            PreferenceToggleSheet(
                title: "Notifications",
                systemImage: "bell",
                description: "A reminder at \(AppPreferences.shared.reminderTimeText) on your build days when you haven't completed a workout yet, so your streak stays alive. Sent by this phone.",
                keyPath: \.notificationsEnabled
            ) { isOn in
                Task {
                    if isOn { await NotificationService.shared.requestAuthorizationIfNeeded() }
                    await NotificationService.shared.scheduleStreakReminders(
                        doneToday: appState.progress.hasStreakToday,
                        streak: appState.progress.displayStreak
                    )
                }
            }
        case .haptics:
            PreferenceToggleSheet(
                title: "Haptic",
                systemImage: "hand.tap.fill",
                description: "Controls impact and feedback vibrations across workouts and battles.",
                keyPath: \.hapticsEnabled
            )
        case .sound:
            PreferenceToggleSheet(
                title: "Sound Effects",
                systemImage: "speaker.wave.2.fill",
                description: "Controls game and interface sound effects.",
                keyPath: \.soundEnabled
            )
        case .feedback:
            FeedbackSheet()
        }
    }

    // MARK: - External actions

    private func contactSupport() {
        guard let url = URL(string: "mailto:contact@pushcraft.app") else {
            showMailDialog = true
            return
        }
        UIApplication.shared.open(url) { success in
            if !success { showMailDialog = true }
        }
    }

    private func openReview() {
        guard let appStoreAppID else {
            showReviewDialog = true
            return
        }
        openURL("https://apps.apple.com/app/id\(appStoreAppID)?action=write-review")
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Child sheet enum

enum SettingsChild: String, Identifiable {
    case account, subscription, notifications, haptics, sound, feedback

    var id: String { rawValue }
}

// MARK: - Row

/// One tappable settings row: icon in a rounded square, title, chevron.
struct SettingsRow: View {
    let title: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xAFC3E8))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.07), in: .rect(cornerRadius: 9, style: .continuous))

                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ivory)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.mist.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleStyle())
    }
}

// MARK: - Shared child sheet scaffold

/// Common scaffold for the child sheets stacked above Settings: drag handle,
/// title with close button, scrollable navy content.
struct SheetScaffold<Content: View>: View {
    let title: String
    var detents: Set<PresentationDetent> = [.medium, .large]
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .frame(maxWidth: .infinity)

            HStack {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.mist)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.08), in: .circle)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 8)

            content()
        }
        .background(Theme.night.ignoresSafeArea())
        .presentationDetents(detents)
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsSheet()
        .environment(AppState())
}
