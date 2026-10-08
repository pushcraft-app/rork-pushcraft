import SwiftUI

// MARK: - 13 Your tower journey

struct TowerJourneyScreen: View {
    /// Called when the staged reveal finishes so the flow can fade the pinned
    /// Continue button in.
    let onCTAReady: () -> Void

    @State private var showTitle = false
    @State private var showGolem = false
    @State private var showBubble = false

    /// Where the painted "START HERE" banner sits in journey.png (853 × 1844).
    private static let imageSize = CGSize(width: 853, height: 1844)
    private static let bannerCenter = CGPoint(x: 0.299, y: 0.798)
    private static let bannerWidth: CGFloat = 0.36

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let scale = max(proxy.size.width / Self.imageSize.width, proxy.size.height / Self.imageSize.height)
                let drawn = CGSize(width: Self.imageSize.width * scale, height: Self.imageSize.height * scale)
                let origin = CGPoint(x: (proxy.size.width - drawn.width) / 2, y: (proxy.size.height - drawn.height) / 2)

                ZStack(alignment: .topLeading) {
                    Image("onboarding_journey_bg")
                        .resizable()
                        .frame(width: drawn.width, height: drawn.height)
                        .offset(x: origin.x, y: origin.y)

                    StartHereBadge(towerName: OnboardingModel.firstTowerName, width: drawn.width * Self.bannerWidth)
                        .position(
                            x: origin.x + drawn.width * Self.bannerCenter.x,
                            y: origin.y + drawn.height * Self.bannerCenter.y
                        )
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clipped()
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            LinearGradient(
                stops: [
                    .init(color: Theme.obNavyDeep.opacity(0.75), location: 0),
                    .init(color: .clear, location: 0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                Text("Your tower journey")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ivory)
                    .shadow(color: .black.opacity(0.5), radius: 8)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .opacity(showTitle ? 1 : 0)

                HStack(alignment: .top, spacing: 6) {
                    Image("golem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                        .opacity(showGolem ? 1 : 0)
                        .scaleEffect(showGolem ? 1 : 0.85, anchor: .bottom)
                        .accessibilityHidden(true)

                    if showBubble {
                        SpeechBubble(
                            text: "Every rep brings you closer to your next tower. Let's start building.",
                            tail: .leading,
                            fontSize: 17
                        )
                        .padding(.top, 10)
                        .transition(.scale(scale: 0.85, anchor: .leading).combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)

                Spacer()
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.6)) { showTitle = true }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.7)) { showGolem = true }
            try? await Task.sleep(for: .milliseconds(750))
            HapticService.ui.thud()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { showBubble = true }
            try? await Task.sleep(for: .milliseconds(500))
            onCTAReady()
        }
    }
}

/// Native "START HERE" plaque that sits over the painted banner.
private struct StartHereBadge: View {
    let towerName: String
    let width: CGFloat

    var body: some View {
        VStack(spacing: -width * 0.03) {
            Text("START HERE")
                .font(.system(size: width * 0.075, weight: .heavy, design: .serif))
                .tracking(0.5)
                .foregroundStyle(Color(hex: 0x2A1A06))
                .padding(.horizontal, width * 0.07)
                .padding(.vertical, width * 0.018)
                .background(
                    .linearGradient(colors: [Color(hex: 0xFFD98A), Color(hex: 0xE2A23A)], startPoint: .top, endPoint: .bottom),
                    in: .capsule
                )
                .zIndex(1)

            Text(towerName)
                .font(.system(size: width * 0.15, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width * 0.92, height: width * 0.25)
                .background(Color(hex: 0x14244A), in: .rect(cornerRadius: width * 0.05, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                        .strokeBorder(
                            .linearGradient(colors: [Color(hex: 0xFFD98A), Color(hex: 0xB37A22)], startPoint: .top, endPoint: .bottom),
                            lineWidth: max(1.5, width * 0.012)
                        )
                }
        }
        .frame(width: width)
        .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
    }
}

// MARK: - 14 How you build

struct HowBuildScreen: View {
    /// Fades the pinned Continue button in once the image has appeared.
    let onCTAReady: () -> Void

    @State private var showImage = false

    var body: some View {
        ZStack {
            Color(hex: 0x051A3A).ignoresSafeArea()

            VStack(spacing: 0) {
                OnboardingHeader(title: "How to build", helper: "Every rep builds something.")
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                Image("onboarding_build_bg")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(showImage ? 1 : 0)
                    .accessibilityLabel("Do push-ups, break blocks, build your tower.")

                Color.clear.frame(height: 96)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.7)) { showImage = true }
            try? await Task.sleep(for: .milliseconds(1200))  // image fade (0.7s) + the 500ms pause
            onCTAReady()
        }
    }
}

// MARK: - 19 Your first build

struct FirstBuildScreen: View {
    let model: OnboardingModel

    @State private var showScene = false
    @State private var showBubble = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(title: "Your first build starts here")
                .padding(.horizontal, 24)
                .padding(.top, 12)

            Spacer(minLength: 8)

            if showBubble {
                SpeechBubble(text: "Ready, \(model.nameOrBuilder)? Let's put your first effort into \(OnboardingModel.firstTowerName).")
                    .padding(.horizontal, 24)
                    .transition(.scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
            } else {
                Color.clear.frame(height: 76)
            }

            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(RadialGradient(colors: [Theme.amberSoft.opacity(0.35), .clear], center: .center, startRadius: 4, endRadius: 170))
                    .frame(width: 340, height: 90)
                    .offset(y: 10)

                Image("oakspire_foundation")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .accessibilityLabel("The empty foundation where Oakspire will rise")

                Image("golem")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .offset(x: -96, y: -92)
                    .accessibilityHidden(true)
            }
            .padding(.top, 70)
            .opacity(showScene ? 1 : 0)
            .scaleEffect(showScene ? 1 : 0.92)

            Spacer(minLength: 8)

            Color.clear.frame(height: 92)
        }
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { showScene = true }
            try? await Task.sleep(for: .milliseconds(500))
            HapticService.ui.thud()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { showBubble = true }
        }
    }
}

// MARK: - 20 / 21 Instructions

struct InstructionScreen: View {
    let title: String
    let body1: String
    var body2: String?
    let imageName: String
    var imageAspect: CGFloat = 1

    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    OnboardingHeader(title: title)

                    Image(imageName)
                        .resizable()
                        .aspectRatio(imageAspect, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                        .opacity(hasAppeared ? 1 : 0)
                        .scaleEffect(hasAppeared ? 1 : 0.95)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(body1)
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ivory)
                        if let body2 {
                            Text(body2)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.mist)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 132)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { hasAppeared = true }
        }
    }
}

// MARK: - 22 Detection tips

struct DetectionTipsScreen: View {
    @State private var hasAppeared = false

    private let tips: [(String, String)] = [
        ("figure.stand", "Make sure you back up enough so your whole body is in frame."),
        ("lightbulb.max.fill", "Make sure the background is well-lit."),
        ("tshirt.fill", "Tuck in any baggy clothes.")
    ]

    var body: some View {
        OnboardingScaffold(title: "Detection Tips") {
            VStack(spacing: 14) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    HStack(spacing: 16) {
                        Image(systemName: tip.0)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.amberSoft)
                            .frame(width: 52, height: 52)
                            .background(Theme.amberSoft.opacity(0.12), in: .rect(cornerRadius: 16, style: .continuous))
                        Text(tip.1)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ivory)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(Theme.obCard, in: .rect(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.obCardBorder, lineWidth: 1)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : 24)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.1), value: hasAppeared)
                }
            }
        }
        .onAppear { hasAppeared = true }
    }
}
