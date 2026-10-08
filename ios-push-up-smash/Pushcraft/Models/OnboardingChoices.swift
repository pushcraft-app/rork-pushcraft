import Foundation

/// A single-choice onboarding answer. `serverValue` is what gets stored.
protocol OnboardingChoice: CaseIterable, Hashable, Identifiable {
    var title: String { get }
    var symbol: String? { get }
    var serverValue: String { get }
}

extension OnboardingChoice where Self: RawRepresentable, Self.RawValue == String {
    var id: String { rawValue }
    var serverValue: String { rawValue }
}

extension OnboardingChoice {
    var symbol: String? { nil }
}

enum MainGoal: String, OnboardingChoice {
    case strength
    case moreReps = "more_reps"
    case consistency
    case fun
    case challenge

    var title: String {
        switch self {
        case .strength: "Get stronger"
        case .moreReps: "Do more push-ups"
        case .consistency: "Build a consistent habit"
        case .fun: "Make exercise more fun"
        case .challenge: "Challenge myself"
        }
    }

    var symbol: String? {
        switch self {
        case .strength: "dumbbell.fill"
        case .moreReps: "repeat"
        case .consistency: "calendar"
        case .fun: "gamecontroller.fill"
        case .challenge: "trophy.fill"
        }
    }
}

enum ExperienceLevel: String, OnboardingChoice {
    case beginner = "new"
    case some
    case regular

    var title: String {
        switch self {
        case .beginner: "I'm just starting"
        case .some: "I've exercised before"
        case .regular: "I exercise regularly"
        }
    }

    var symbol: String? {
        switch self {
        case .beginner: "leaf.fill"
        case .some: "figure.walk"
        case .regular: "figure.run"
        }
    }
}

enum GenderChoice: String, OnboardingChoice {
    case man
    case woman
    case undisclosed

    var title: String {
        switch self {
        case .man: "Male"
        case .woman: "Female"
        case .undisclosed: "Prefer not to say"
        }
    }
}

enum ExerciseFrequency: String, OnboardingChoice {
    case noneRegular = "none_regular"
    case oneTwo = "one_two"
    case threeFour = "three_four"
    case fivePlus = "five_plus"

    var title: String {
        switch self {
        case .noneRegular: "Not regularly"
        case .oneTwo: "1–2 days a week"
        case .threeFour: "3–4 days a week"
        case .fivePlus: "5+ days a week"
        }
    }
}

enum Agreement: String, OnboardingChoice {
    case yes
    case sometimes
    case no

    var title: String {
        switch self {
        case .yes: "Yes"
        case .sometimes: "Sometimes"
        case .no: "Not really"
        }
    }
}

enum PushupCapacity: String, OnboardingChoice {
    case zero
    case oneFive = "one_five"
    case sixTen = "six_ten"
    case elevenTwenty = "eleven_twenty"
    case twentyoneThirty = "twentyone_thirty"
    case thirtyonePlus = "thirtyone_plus"
    case unknown

    var title: String {
        switch self {
        case .zero: "I'm still working toward my first"
        case .oneFive: "1–5"
        case .sixTen: "6–10"
        case .elevenTwenty: "11–20"
        case .twentyoneThirty: "21–30"
        case .thirtyonePlus: "31+"
        case .unknown: "I'm not sure"
        }
    }
}

enum HeightUnit: String, CaseIterable {
    case cm
    case ftIn = "ft_in"

    var title: String {
        switch self {
        case .cm: "cm"
        case .ftIn: "ft / in"
        }
    }
}

/// ISO weekdays: 1 = Monday … 7 = Sunday.
enum Weekday: Int, CaseIterable, Identifiable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    var short: String { String(title.prefix(3)) }
}
