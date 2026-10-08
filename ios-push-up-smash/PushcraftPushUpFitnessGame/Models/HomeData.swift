import Foundation

/// Completion state of a construction stage.
enum StageState: Sendable {
    case completed
    case current
    case locked
}

/// One construction stage of the current tower, measured in reps.
struct JourneyStage: Identifiable, Sendable {
    let number: Int
    let name: String
    let state: StageState
    let repsRequired: Int
    let repsDone: Int

    var id: Int { number }

    var progress: Double {
        repsRequired == 0 ? 0 : min(Double(repsDone) / Double(repsRequired), 1)
    }
}

/// Everything the Home page, Journey and workout prep show. Built from the
/// server dashboard (`ProgressStore.homeData`); `mock` is for previews only.
struct HomeData: Sendable {
    let streak: Int
    let xp: Int
    let coins: Int
    let towerName: String
    let stageNumber: Int
    let totalStages: Int
    let stageName: String
    let repsIntoStage: Int
    let stageTarget: Int
    let sets: Int
    let repsPerSet: Int
    let estimatedMinutes: Int
    let xpPerWorkout: Int
    let rewardName: String
    let journey: [JourneyStage]
    /// True once the final tower is finished; reps still count toward stats.
    let isAllComplete: Bool

    /// Completion of the CURRENT construction stage, 0...1.
    var stageProgress: Double {
        stageTarget == 0 ? 0 : min(Double(repsIntoStage) / Double(stageTarget), 1)
    }

    var stagePercent: Int { Int((stageProgress * 100).rounded()) }
    var totalPlannedReps: Int { sets * repsPerSet }
    var repsToGo: Int { max(stageTarget - repsIntoStage, 0) }

    var coinsDisplay: String {
        String(coins)
    }
}

extension HomeData {
    static let stageNames = [
        "The Foundation", "The Entrance", "The Walls", "The Courtyard", "The Bastion",
        "The Spire", "The Beacon", "The Crown", "The Summit"
    ]

    /// Shown while the dashboard is loading for the first time.
    static let placeholder = HomeData(
        streak: 0,
        xp: 0,
        coins: 0,
        towerName: "Your Tower",
        stageNumber: 1,
        totalStages: 9,
        stageName: "The Foundation",
        repsIntoStage: 0,
        stageTarget: 30,
        sets: 3,
        repsPerSet: 10,
        estimatedMinutes: 5,
        xpPerWorkout: 100,
        rewardName: "Stone",
        journey: [],
        isAllComplete: false
    )

    /// Preview sample matching the Home page design reference.
    static let mock = HomeData(
        streak: 5,
        xp: 840,
        coins: 1250,
        towerName: "Stonewatch",
        stageNumber: 2,
        totalStages: 9,
        stageName: "The Entrance",
        repsIntoStage: 27,
        stageTarget: 55,
        sets: 3,
        repsPerSet: 10,
        estimatedMinutes: 5,
        xpPerWorkout: 100,
        rewardName: "Stone",
        journey: stageNames.enumerated().map { index, name in
            let number = index + 1
            let required = 50 + index * 5
            return JourneyStage(
                number: number,
                name: name,
                state: number < 2 ? .completed : number == 2 ? .current : .locked,
                repsRequired: required,
                repsDone: number < 2 ? required : number == 2 ? 27 : 0
            )
        },
        isAllComplete: false
    )
}
