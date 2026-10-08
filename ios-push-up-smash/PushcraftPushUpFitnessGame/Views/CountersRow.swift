import SwiftUI

/// Streak / XP / coins pill row shared by the Home, Towers and Battles headers.
/// Tapping the coin pill opens the "store coming soon" teaser.
struct CountersRow: View {
    let streak: Int
    let xp: Int
    let coinsDisplay: String

    @State private var showStoreSheet = false

    var body: some View {
        HStack(spacing: 6) {
            StatPill(value: "\(streak)", valueColor: Theme.streakOrange) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Theme.amberSoft, Color(hex: 0xFF6B1E)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            StatPill(value: "\(xp)", suffix: "XP", valueColor: Theme.progressCyan) {
                EmptyView()
            }
            Spacer(minLength: 6)
            Button {
                showStoreSheet = true
            } label: {
                StatPill(value: coinsDisplay, valueColor: Theme.gold) {
                    Image("gold_coin_star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("\(coinsDisplay) coins. Store coming soon.")
        }
        .sheet(isPresented: $showStoreSheet) {
            StoreComingSoonSheet()
        }
    }
}

/// Teaser shown when tapping the coin badge — the coin store isn't live yet.
private struct StoreComingSoonSheet: View {
    var body: some View {
        VStack(spacing: 14) {
            Image("gold_coin_star")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .shadow(color: Theme.gold.opacity(0.6), radius: 14)

            Text("Store coming soon")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)

            Text("Spend your coins on boosters and cosmetics once the shop opens. Keep building!")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.towersNavy)
    }
}
