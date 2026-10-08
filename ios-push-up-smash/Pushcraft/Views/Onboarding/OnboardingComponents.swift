import SwiftUI

// MARK: - Background

/// Deep navy canvas with a soft glow, shared by onboarding screens.
struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.obNavy, Theme.obNavyDeep], startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Color(hex: 0x1E4A8F, opacity: 0.45), .clear],
                center: UnitPoint(x: 0.5, y: 0.12),
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Top bar

/// Back chevron plus the questionnaire progress bar.
struct OnboardingTopBar: View {
    let progress: Double?
    let canGoBack: Bool
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button {
                HapticService.ui.tap()
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ivory)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(PressScaleStyle())
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)
            .accessibilityLabel("Back")

            if let progress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(.linearGradient(colors: [Theme.amberSoft, Theme.amberDeep], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, proxy.size.width * progress))
                            .shadow(color: Theme.amberDeep.opacity(0.6), radius: 6)
                    }
                }
                .frame(height: 6)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
                .accessibilityElement()
                .accessibilityLabel("Progress")
                .accessibilityValue("\(Int(progress * 100)) percent")
            } else {
                Spacer()
            }

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 10)
    }
}

// MARK: - Buttons

/// Wide amber call-to-action with a darker bottom edge.
struct OnboardingPrimaryButton: View {
    let title: String
    var isEnabled = true
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticService.ui.tap()
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(Theme.buttonInk)
                } else {
                    Text(title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.buttonInk)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.amberEdge)
                        .offset(y: 4)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.linearGradient(colors: [Theme.amberSoft, Theme.amberDeep], startPoint: .top, endPoint: .bottom))
                }
            }
            .shadow(color: Theme.amberDeep.opacity(isEnabled ? 0.35 : 0), radius: 14, y: 6)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

/// Quiet text button used under the primary action.
struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticService.ui.tap()
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.mist)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// The pinned bottom call-to-action shared by every onboarding step. It stays
/// in place while pages slide behind it, like switching between tabs.
struct PersistentCTA: View {
    let title: String
    var isEnabled = true
    var isLoading = false
    var secondaryTitle: String?
    let onPrimary: () -> Void
    var onSecondary: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            if let secondaryTitle {
                OnboardingSecondaryButton(title: secondaryTitle, action: onSecondary)
            }
            OnboardingPrimaryButton(
                title: title,
                isEnabled: isEnabled,
                isLoading: isLoading,
                action: onPrimary
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background {
            LinearGradient(
                stops: [
                    .init(color: Theme.obNavyDeep.opacity(0), location: 0),
                    .init(color: Theme.obNavyDeep.opacity(0.9), location: 0.45),
                    .init(color: Theme.obNavyDeep, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Layout

/// Standard question screen: heading, helper, content. The call-to-action is
/// pinned by the flow view, so screens only leave clearance at the bottom.
struct OnboardingScaffold<Content: View>: View {
    let title: String
    var helper: String?
    var scrolls = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        if scrolls {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    OnboardingHeader(title: title, helper: helper)
                    content()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 132)
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingHeader(title: title, helper: helper)
                content()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 104)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

struct OnboardingHeader: View {
    let title: String
    var helper: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .fixedSize(horizontal: false, vertical: true)
            if let helper {
                Text(helper)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mist)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Options

/// Tappable answer card used by single and multi-choice questions.
struct OnboardingOptionRow: View {
    let title: String
    var symbol: String?
    let isSelected: Bool
    var isMulti = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticService.ui.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isSelected ? Theme.buttonInk : Theme.amberSoft)
                        .frame(width: 40, height: 40)
                        .background(
                            isSelected ? AnyShapeStyle(Theme.amberSoft) : AnyShapeStyle(Theme.amberSoft.opacity(0.12)),
                            in: .rect(cornerRadius: 12, style: .continuous)
                        )
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                indicator
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .background(
                isSelected ? Theme.amberSoft.opacity(0.12) : Theme.obCard.opacity(0.85),
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Theme.amberSoft : Theme.obCardBorder, lineWidth: isSelected ? 2 : 1)
            }
            .scaleEffect(isSelected ? 1.0 : 0.985)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var indicator: some View {
        let shape = isMulti ? AnyShape(RoundedRectangle(cornerRadius: 7, style: .continuous)) : AnyShape(Circle())
        ZStack {
            shape
                .stroke(isSelected ? Theme.amberSoft : .white.opacity(0.3), lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                shape
                    .fill(Theme.amberSoft)
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.buttonInk)
            }
        }
    }
}

/// Quote-style card for the "Does this sound like you?" questions.
struct StatementCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "quote.opening")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.amberSoft)
            Text(text)
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.obCard, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22)
                .fill(Theme.amberSoft)
                .frame(width: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.obCardBorder, lineWidth: 1)
        }
    }
}

// MARK: - Speech bubble

/// The golem's speech bubble. Optionally types its text in.
struct SpeechBubble: View {
    enum Tail { case bottom, leading, none }

    let text: String
    var tail: Tail = .bottom
    var typewriter = true
    var fontSize: CGFloat = 19

    @State private var visibleCount = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text).hidden()
            Text(String(text.prefix(visibleCount)))
        }
        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
        .foregroundStyle(Theme.paywallInk)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.ivory)
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        }
        .overlay(alignment: tailAlignment) {
            if tail != .none {
                BubbleTail()
                    .fill(Theme.ivory)
                    .frame(width: 22, height: 14)
                    .rotationEffect(.degrees(tail == .leading ? 90 : 0))
                    .offset(x: tail == .leading ? -16 : 0, y: tail == .bottom ? 12 : 0)
                    .padding(tail == .bottom ? .leading : .top, tail == .bottom ? 44 : 22)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(text)
        .task(id: text) {
            guard typewriter else {
                visibleCount = text.count
                return
            }
            visibleCount = 0
            for index in 1...max(text.count, 1) {
                try? await Task.sleep(for: .milliseconds(22))
                if Task.isCancelled { return }
                visibleCount = index
            }
        }
    }

    private var tailAlignment: Alignment {
        switch tail {
        case .bottom: .bottomLeading
        case .leading: .topLeading
        case .none: .center
        }
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX * 0.7, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Legal

/// Terms / Privacy line under sign-in buttons.
struct LegalLine: View {
    var body: some View {
        Text("By continuing, you agree to our [Terms of Service](https://www.pushcraft.app/terms) and [Privacy Policy](https://www.pushcraft.app/privacy-policy).")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.mist.opacity(0.8))
            .tint(Theme.amberSoft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
