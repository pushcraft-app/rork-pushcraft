import Foundation

/// The exercises the camera can count. One exercise is chosen per session —
/// routines never mix exercises. Both exercises earn reps that advance any
/// tower, so no tower ever requires a specific movement.
enum Exercise: String, CaseIterable, Sendable, Identifiable {
    case pushUps
    case sitUps

    var id: String { rawValue }

    /// The value stored in the database (`push_ups` / `sit_ups`).
    var serverValue: String {
        switch self {
        case .pushUps: "push_ups"
        case .sitUps: "sit_ups"
        }
    }

    init?(serverValue: String) {
        switch serverValue {
        case "push_ups": self = .pushUps
        case "sit_ups": self = .sitUps
        default: return nil
        }
    }

    /// Title-case name used in pickers and cards.
    var displayName: String {
        switch self {
        case .pushUps: "Push-Ups"
        case .sitUps: "Sit-Ups"
        }
    }

    /// Lowercase noun for counts, e.g. "23 push-ups".
    var unitName: String {
        switch self {
        case .pushUps: "push-ups"
        case .sitUps: "sit-ups"
        }
    }

    /// The rep-counting movement, used in coach cues.
    var actionName: String {
        switch self {
        case .pushUps: "push up"
        case .sitUps: "sit up"
        }
    }

    /// Battle challenge framing — both players always perform the same
    /// exercise, selected by the host when creating the battle.
    var challengeTitle: String {
        switch self {
        case .pushUps: "Most push-ups in 60 seconds"
        case .sitUps: "Most sit-ups in 60 seconds"
        }
    }

    var challengeDescription: String {
        switch self {
        case .pushUps: "Record as many push-ups as you can in 60 seconds. The higher count wins the battle."
        case .sitUps: "Record as many sit-ups as you can in 60 seconds. The higher count wins the battle."
        }
    }
}
