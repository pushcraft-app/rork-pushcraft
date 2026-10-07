import SwiftUI

/// Charge bar: fills as the user goes down, drains as they push back up.
/// Turns gold once the rep is "charged" (deep enough to count).
struct DepthMeter: View {
    let tracking: RepTracking

    var body: some View {
        let isCalibrating = tracking.phase == .calibrating
        let isCharged = tracking.phase == .charged
        let fill = isCalibrating ? tracking.calibration : tracking.depth
        let color: Color = isCalibrating ? .white : (isCharged ? Theme.gold : Theme.cyan)

        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.7), color, .white.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fill > 0.01 ? max(width * fill, proxy.size.height) : 0)
                    .shadow(color: color.opacity(0.9), radius: 10)

                if !isCalibrating {
                    Capsule()
                        .fill(.white.opacity(isCharged ? 0 : 0.5))
                        .frame(width: 3, height: proxy.size.height * 0.7)
                        .offset(x: width * RepDetector.downThreshold - 1.5)
                }
            }
        }
        .frame(height: 20)
        .padding(5)
        .background(Capsule().fill(.black.opacity(0.5)))
        .overlay {
            Capsule()
                .strokeBorder(color.opacity(0.95), lineWidth: 2)
                .shadow(color: color.opacity(0.9), radius: 8)
        }
        .scaleEffect(isCharged ? 1.03 : 1)
        .animation(.interactiveSpring(response: 0.16, dampingFraction: 0.85), value: fill)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isCharged)
        .accessibilityLabel("Push-up depth")
        .accessibilityValue("\(Int(fill * 100)) percent")
    }
}
