import SwiftUI
import UIKit

/// 23 — First playable challenge: the real camera engine, one crate that
/// breaks after 4 valid push-ups, then a celebration. Tutorial only: these
/// reps are not saved to the account.
struct IntroWorkoutScreen: View {
    let onFinish: (Int) -> Void
    let onSkip: () -> Void

    @State private var engine = GameEngine(exercise: .pushUps, firstBlockHealth: OnboardingModel.introReps)
    @State private var isCelebrating = false
    @State private var hasFinished = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private var target: Int { OnboardingModel.introReps }

    var body: some View {
        ZStack {
            CameraPreviewView(displayLayer: engine.camera.displayLayer)
                .ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.6), location: 0),
                    .init(color: .clear, location: 0.32),
                    .init(color: .clear, location: 0.6),
                    .init(color: .black.opacity(0.7), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            SkeletonView(pose: engine.pose)
                .ignoresSafeArea()
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { size in
                    engine.layout.screenSize = size
                }

            hud
                .opacity(isCelebrating ? 0 : 1)

            EffectsOverlay(engine: engine)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if isCelebrating {
                IntroCelebration(reps: engine.reps) {
                    finish()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if let message = cameraMessage {
                cameraCard(message)
            }
        }
        .background(Color.black)
        .statusBarHidden()
        .onAppear { engine.start() }
        .onDisappear { engine.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !hasFinished {
                engine.start()
            } else if phase == .background {
                engine.stop()
            }
        }
        .onChange(of: engine.smashCount) { _, count in
            guard count >= 1, !isCelebrating else { return }
            engine.isAcceptingReps = false
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                HapticService.ui.success()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    isCelebrating = true
                }
            }
        }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        engine.stop()
        onFinish(engine.reps)
    }

    // MARK: - HUD

    private var hud: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    HapticService.ui.tap()
                    hasFinished = true
                    engine.stop()
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Theme.panel, in: .capsule)
                        .overlay { Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1) }
                }
                .buttonStyle(PressScaleStyle())

                Spacer()

                HStack(spacing: 7) {
                    Image(systemName: "target")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(min(engine.reps, target)) / \(target)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: engine.reps)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Theme.panel, in: .capsule)
                .overlay { Capsule().strokeBorder(Theme.amberSoft.opacity(0.7), lineWidth: 1.5) }
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    engine.layout.coinTarget = CGPoint(x: frame.midX, y: frame.midY)
                }
                .accessibilityLabel("\(engine.reps) of \(target) push-ups")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text("Smash the crate with \(target) push-ups")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .shadow(color: .black.opacity(0.7), radius: 4)
                .padding(.top, 16)

            blockStage
                .padding(.top, 18)

            Spacer(minLength: 16)

            VStack(spacing: 10) {
                DepthMeter(tracking: engine.tracking)
                    .padding(.horizontal, 40)
                CueView(cue: engine.cue, exercise: .pushUps)
            }
            .padding(.bottom, 20)
        }
    }

    private var blockStage: some View {
        let isCharging = engine.tracking.phase == .charging || engine.tracking.phase == .charged
        let damage = engine.spec.health > 0 ? Double(engine.hitsTaken) / Double(engine.spec.health) : 0

        return VStack(spacing: 14) {
            BlockView(
                tier: engine.spec.tier,
                seed: engine.blockSeed,
                damage: damage,
                charge: isCharging ? engine.tracking.depth : 0,
                isCharged: engine.tracking.phase == .charged,
                hitTrigger: engine.hitCount
            )
            .opacity(engine.smashCount >= 1 ? 0 : 1)
            .scaleEffect(engine.blockPhase == .shattered ? 1.35 : 1)
            .animation(.easeOut(duration: 0.14), value: engine.blockPhase)
            .frame(width: 150, height: 150)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                engine.layout.blockFrame = frame
            }

            HealthPips(total: engine.spec.health, remaining: engine.health)
                .opacity(engine.smashCount >= 1 ? 0 : 1)
        }
    }

    // MARK: - Camera states

    private var cameraMessage: (String, String, Bool)? {
        switch engine.cameraStatus {
        case .denied:
            ("Camera access needed", "PushcraftPushUpFitnessGame counts your push-ups with the camera. Video never leaves your phone.", true)
        case .noCamera:
            ("No camera found", "This device doesn't have a camera available right now.", false)
        case .failed:
            ("Camera couldn't start", "Something went wrong starting the camera.", false)
        case .idle, .running:
            nil
        }
    }

    private func cameraCard(_ message: (String, String, Bool)) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Theme.amberSoft)
            Text(message.0)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
            Text(message.1)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
            if message.2 {
                OnboardingPrimaryButton(title: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
            OnboardingSecondaryButton(title: "Skip for now") {
                hasFinished = true
                engine.stop()
                onSkip()
            }
        }
        .padding(24)
        .background(Theme.obNavy, in: .rect(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.obCardBorder, lineWidth: 1)
        }
        .padding(.horizontal, 24)
    }
}

/// "Crate smashed!" moment after the 4th rep.
private struct IntroCelebration: View {
    let reps: Int
    let onContinue: () -> Void

    @State private var burst = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            ForEach(0..<14, id: \.self) { index in
                let angle = Double(index) / 14 * 2 * .pi
                Image(systemName: index.isMultiple(of: 3) ? "star.fill" : "sparkle")
                    .font(.system(size: index.isMultiple(of: 2) ? 18 : 12, weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 2) ? Theme.gold : Theme.amberSoft)
                    .offset(x: burst ? cos(angle) * 150 : 0, y: burst ? sin(angle) * 150 - 60 : -60)
                    .opacity(burst ? 0 : 1)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 18) {
                Text("CRATE SMASHED!")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(
                        .linearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Theme.gold.opacity(0.8), radius: 14)
                    .scaleEffect(burst ? 1 : 0.6)

                Text(reps == 1 ? "1 push-up" : "\(reps) push-ups")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ivory)

                OnboardingPrimaryButton(title: "Continue", action: onContinue)
                    .frame(maxWidth: 320)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { burst = true }
        }
    }
}
