import SwiftUI

/// "UP NEXT" card describing the next workout within the current construction stage.
struct UpNextCard: View {
    let data: HomeData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UP NEXT")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(Theme.mist)

            HStack(spacing: 12) {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(data.isAllComplete ? "Bonus workout" : "Stage \(data.stageNumber) workout")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("\(data.sets) sets × \(data.repsPerSet) reps")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 13, weight: .semibold))
                        Text("About \(data.estimatedMinutes) min")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Theme.mist)
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 1, height: 56)

                VStack(spacing: 2) {
                    Image("stone_blocks_sparkle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                    Text("+ \(data.rewardName)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ivory)
                    Text("(builds your tower)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 96)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardFill, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.pillBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
    }
}

#Preview {
    UpNextCard(data: .mock)
        .padding()
        .background(Color(hex: 0x0A1730))
}
