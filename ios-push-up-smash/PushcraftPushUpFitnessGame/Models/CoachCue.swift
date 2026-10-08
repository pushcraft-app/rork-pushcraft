import SwiftUI

/// The single instruction shown under the depth meter.
enum CoachCue: Hashable {
    case getInFrame
    case holdTop
    case goDown
    case smashIt
    case smashed

    /// Default (push-up) phrasing for previews and simple callers.
    var title: String { title(for: .pushUps) }
    var subtitle: String? { subtitle(for: .pushUps) }

    func title(for exercise: Exercise) -> String {
        switch self {
        case .getInFrame: "GET IN FRAME"
        case .holdTop: "HOLD THE START"
        case .goDown: exercise == .sitUps ? "SIT UP TO CHARGE" : "GO DOWN TO CHARGE"
        case .smashIt: exercise == .sitUps ? "SIT UP — SMASH IT!" : "PUSH UP — SMASH IT!"
        case .smashed: "BLOCK SMASHED!"
        }
    }

    func subtitle(for exercise: Exercise) -> String? {
        switch self {
        case .getInFrame:
            exercise == .sitUps
                ? "Prop your phone up to the side, then lie on your back"
                : "Prop your phone up facing you, then get into a plank"
        case .holdTop:
            exercise == .sitUps
                ? "Lie flat, stay still — calibrating"
                : "Arms straight, stay still — calibrating"
        case .goDown, .smashIt: nil
        case .smashed: "A tougher block is dropping in"
        }
    }

    var tint: Color {
        switch self {
        case .getInFrame, .goDown: Theme.cyan
        case .holdTop: .white
        case .smashIt, .smashed: Theme.gold
        }
    }

    var symbol: String? {
        switch self {
        case .getInFrame: "person.fill.viewfinder"
        case .holdTop: "hand.raised.fill"
        case .smashed: "sparkles"
        case .goDown, .smashIt: nil
        }
    }
}
