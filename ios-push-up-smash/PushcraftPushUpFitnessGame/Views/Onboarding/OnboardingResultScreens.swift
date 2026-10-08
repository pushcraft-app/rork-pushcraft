import StoreKit
import SwiftUI

// MARK: - 24 First earned progress

struct FirstRewardScreen: View {
    let model: OnboardingModel

    @State private var showBuilt = false
    @State private var showBubble = false
    @State private var sparkle = false
    @Environment(\.requestReview) private var requestReview

    private var reps: Int { model.makeAnswers().introWorkoutReps ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    OnboardingHeader(title: "Your first progress, earned")

                    HStack(alignment: .top, spacing: 6) {
                        Image("golem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 92, height: 92)
                            .accessibilityHidden(true)
                        if showBubble {
                            SpeechBubble(
                                text: "That's your effort, \(model.nameOrBuilder). Your first build is underway.",
                                tail: .leading,
                                fontSize: 17
                            )
                            .padding(.top, 8)
                            .transition(.scale(scale: 0.85, anchor: .leading).combined(with: .opacity))
                        }
                        Spacer(minLength: 0)
                    }

                    ZStack {
                        Ellipse()
                            .fill(RadialGradient(colors: [Theme.amberSoft.opacity(showBuilt ? 0.45 : 0.15), .clear], center: .center, startRadius: 4, endRadius: 180))
                            .frame(width: 340, height: 120)
                            .offset(y: 60)

                        Image("oakspire_foundation")
                            .resizable()
                            .scaledToFit()
                            .opacity(showBuilt ? 0 : 1)
                        Image("oakspire_foundation_built")
                            .resizable()
                            .scaledToFit()
                            .opacity(showBuilt ? 1 : 0)
                            .scaleEffect(showBuilt ? 1 : 0.96)

                        ForEach(0..<8, id: \.self) { index in
                            let angle = Double(index) / 8 * 2 * .pi
                            Image(systemName: "sparkle")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.gold)
                                .offset(x: sparkle ? cos(angle) * 150 : 0, y: sparkle ? sin(angle) * 80 : 0)
                                .opacity(sparkle ? 0 : (showBuilt ? 1 : 0))
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: 320)
                    .accessibilityElement()
                    .accessibilityLabel("Oakspire's foundation, with new stones laid")

                    HStack(spacing: 12) {
                        metric(value: reps == 1 ? "1" : "\(reps)", label: reps == 1 ? "push-up" : "push-ups", symbol: "figure.strengthtraining.functional")
                        metric(value: OnboardingModel.firstTowerName, label: OnboardingModel.firstStageName, symbol: "building.columns.fill")
                    }

                    Text("A preview of your first tower. Your reps start building for real once you save your progress.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 132)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            HapticService.ui.thud()
            withAnimation(.easeInOut(duration: 1.1)) { showBuilt = true }
            withAnimation(.easeOut(duration: 1.2).delay(0.4)) { sparkle = true }
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { showBubble = true }
            try? await Task.sleep(for: .milliseconds(1800))
            requestReview()
        }
    }

    private func metric(value: String, label: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.amberSoft)
                .frame(width: 40, height: 40)
                .background(Theme.amberSoft.opacity(0.12), in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.obCard, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.obCardBorder, lineWidth: 1)
        }
    }
}

// MARK: - 25 First-tower forecast

struct ForecastScreen: View {
    let model: OnboardingModel

    private var dateText: String {
        guard let date = model.forecastDate else { return "soon" }
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        return sameYear
            ? date.formatted(.dateTime.month(.abbreviated).day())
            : date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var daysText: String {
        let count = model.workoutDays.count
        return count == 1 ? "1 day a week" : "\(count) days a week"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    OnboardingHeader(title: "Your first tower is within reach by \(dateText)")

                    Text("You have amazing potential!")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            .linearGradient(colors: [Theme.gold, Theme.amberDeep], startPoint: .leading, endPoint: .trailing)
                        )

                    ForecastGraph(endLabel: dateText)
                        .frame(height: 250)

                    Text("At \(OnboardingModel.sessionGoal) reps per session, \(daysText), you could finish \(OnboardingModel.firstTowerName) around \(dateText).")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ivory)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Every rep brings you closer to your next tower")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 132)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// Curve that draws from "Today" up to the tower at the forecast date.
private struct ForecastGraph: View {
    let endLabel: String

    @State private var progress: CGFloat = 0
    @State private var showTower = false

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let size = proxy.size
                let start = CGPoint(x: 14, y: size.height - 14)
                let end = CGPoint(x: size.width - 34, y: 38)

                ZStack(alignment: .topLeading) {
                    ForEach(1..<4, id: \.self) { line in
                        Path { path in
                            let y = size.height * CGFloat(line) / 4
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                    }

                    curveArea(start: start, end: end, height: size.height)
                        .fill(.linearGradient(colors: [Theme.amberSoft.opacity(0.32), .clear], startPoint: .top, endPoint: .bottom))
                        .opacity(Double(progress))

                    curve(start: start, end: end)
                        .trim(from: 0, to: progress)
                        .stroke(
                            .linearGradient(colors: [Theme.amberDeep, Theme.gold], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .shadow(color: Theme.amberDeep.opacity(0.7), radius: 8)

                    Circle()
                        .fill(Theme.ivory)
                        .frame(width: 14, height: 14)
                        .overlay { Circle().strokeBorder(Theme.amberDeep, lineWidth: 3) }
                        .position(start)

                    Image("paywall_tower")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                        .shadow(color: Theme.gold.opacity(0.7), radius: 12)
                        .scaleEffect(showTower ? 1 : 0.2)
                        .opacity(showTower ? 1 : 0)
                        .position(x: end.x, y: end.y - 6)
                        .accessibilityHidden(true)
                }
            }
            .background(Theme.obCard.opacity(0.6), in: .rect(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.obCardBorder, lineWidth: 1)
            }

            HStack {
                Text("Today")
                Spacer()
                Text(endLabel)
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.mist)
            .padding(.horizontal, 6)
        }
        .accessibilityElement()
        .accessibilityLabel("Forecast from today to \(endLabel)")
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeInOut(duration: 1.6)) { progress = 1 }
            try? await Task.sleep(for: .milliseconds(1550))
            HapticService.ui.thud()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { showTower = true }
        }
    }

    private func curve(start: CGPoint, end: CGPoint) -> Path {
        Path { path in
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x + (end.x - start.x) * 0.45, y: start.y),
                control2: CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y + (start.y - end.y) * 0.25)
            )
        }
    }

    private func curveArea(start: CGPoint, end: CGPoint, height: CGFloat) -> Path {
        var path = curve(start: start, end: end)
        path.addLine(to: CGPoint(x: end.x, y: height))
        path.addLine(to: CGPoint(x: start.x, y: height))
        path.closeSubpath()
        return path
    }
}

// MARK: - 28 Save your progress

struct SaveProgressScreen: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ZStack(alignment: .bottomLeading) {
                        Image(model.didIntroWorkout ? "oakspire_foundation_built" : "oakspire_foundation")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 210)
                            .offset(x: 70, y: 0)
                            .accessibilityHidden(true)
                        Image("golem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 170, height: 170)
                            .offset(x: -40, y: 10)
                            .accessibilityHidden(true)
                    }
                    .frame(height: 190)
                    .padding(.top, 8)

                    Text("Save your progress")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.ivory)
                        .multilineTextAlignment(.center)

                    Text(model.didIntroWorkout
                         ? "Keep your tower progress and continue your journey."
                         : "Save your starting goal and begin your journey.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 14) {
                AuthButtons {
                    model.awaitingSignUp = true
                }
                LegalLine()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - 29 Setting up account

struct SetupProgressView: View {
    @Environment(AppState.self) private var appState
    @State private var progress: [CGFloat] = [0, 0, 0]

    private let titles = [
        "Setting up your profile",
        "Building your workout plan",
        "Generating your tower roadmap"
    ]

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 34) {
                Image("golem")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .accessibilityHidden(true)

                Text("We're setting everything up for you")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ivory)
                    .multilineTextAlignment(.center)

                VStack(spacing: 22) {
                    ForEach(titles.indices, id: \.self) { index in
                        SetupBar(title: titles[index], progress: progress[index])
                    }
                }
            }
            .padding(.horizontal, 28)
        }
        .task { await run() }
    }

    private func run() async {
        let save = Task { await appState.completeOnboardingSave() }
        for index in titles.indices {
            withAnimation(.easeInOut(duration: 1.3)) { progress[index] = 1 }
            try? await Task.sleep(for: .milliseconds(1350))
            HapticService.ui.success()
        }
        await save.value
        try? await Task.sleep(for: .milliseconds(350))
        withAnimation(.easeInOut(duration: 0.35)) {
            appState.onboarding.finishSetup()
        }
    }
}

private struct SetupBar: View {
    let title: String
    let progress: CGFloat

    private var isDone: Bool { progress >= 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                Spacer()
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isDone ? Theme.gold : Theme.mist.opacity(0.6))
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.spring(response: 0.35, dampingFraction: 0.6).delay(1.3), value: isDone)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(.linearGradient(colors: [Theme.amberSoft, Theme.amberDeep], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * progress)
                        .shadow(color: Theme.amberDeep.opacity(0.6), radius: 6)
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? "Done" : "In progress")
    }
}
