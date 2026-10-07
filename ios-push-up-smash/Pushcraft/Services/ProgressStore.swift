import Foundation
import Observation
import Supabase
import UIKit

/// The signed-in user's profile, stats and tower progress from the server.
/// Every counter in the app reads from here, so values stay consistent.
@Observable
final class ProgressStore {
    private(set) var dashboard: DashboardDTO?
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var avatarData: Data?

    @ObservationIgnored private var loadedAvatarPath: String?

    var hasLoaded: Bool { dashboard != nil }
    var displayName: String { dashboard?.profile.displayName ?? "" }
    var rules: RulesDTO? { dashboard?.rules }
    var stats: StatsDTO? { dashboard?.stats }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dto: DashboardDTO = try await Backend.client.rpc("get_my_dashboard").execute().value
            dashboard = dto
            loadError = nil
            await loadAvatarIfNeeded()
            await NotificationService.shared.scheduleStreakReminders(doneToday: hasStreakToday, streak: displayStreak)
        } catch {
            print("[Progress] Dashboard load failed: \(error.localizedDescription)")
            loadError = BackendFailure.isOffline(error)
                ? "You're offline. Showing your last synced progress."
                : "Couldn't load your progress."
        }
    }

    func reset() {
        dashboard = nil
        avatarData = nil
        loadedAvatarPath = nil
        loadError = nil
    }

    private func loadAvatarIfNeeded() async {
        let path = dashboard?.profile.avatarPath
        guard path != loadedAvatarPath else { return }
        guard let path else {
            avatarData = nil
            loadedAvatarPath = nil
            return
        }
        do {
            avatarData = try await Backend.client.storage.from("avatars").download(path: path)
            loadedAvatarPath = path
        } catch {
            print("[Progress] Avatar download failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Streak

    /// The streak judged against today: it reads 0 once a full day is missed,
    /// even before anything syncs.
    var displayStreak: Int {
        guard let stats, let last = stats.lastStreakDate else { return 0 }
        let today = BackendDates.dayString(Date())
        let yesterday = BackendDates.dayString(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        return last >= yesterday || last == today ? stats.currentStreak : 0
    }

    var hasStreakToday: Bool {
        stats?.lastStreakDate == BackendDates.dayString(Date())
    }

    // MARK: - Derived screen data

    var homeData: HomeData {
        guard let d = dashboard else { return .placeholder }

        let active = d.progress.first { $0.status == "in_progress" }
        let towersByOrder = d.towers.sorted { $0.sortOrder < $1.sortOrder }
        let lastCompleted = towersByOrder.last { tower in
            d.progress.contains { $0.towerId == tower.id && $0.status == "completed" }
        }
        let tower = towersByOrder.first { $0.id == active?.towerId } ?? lastCompleted ?? towersByOrder.first
        let stages = d.stages.filter { $0.towerId == tower?.id }.sorted { $0.stageNumber < $1.stageNumber }
        let isAllComplete = active == nil && lastCompleted != nil

        let currentStage = active?.currentStage ?? stages.count
        let stageTarget = active?.stageTarget ?? stages.last?.repsRequired ?? 0
        let repsIntoStage = active?.repsIntoStage ?? stageTarget
        let stageName = stages.first { $0.stageNumber == currentStage }?.name ?? ""

        let journey = stages.map { stage -> JourneyStage in
            if isAllComplete || stage.stageNumber < currentStage {
                return JourneyStage(number: stage.stageNumber, name: stage.name, state: .completed, repsRequired: stage.repsRequired, repsDone: stage.repsRequired)
            }
            if stage.stageNumber == currentStage {
                return JourneyStage(number: stage.stageNumber, name: stage.name, state: .current, repsRequired: stageTarget, repsDone: repsIntoStage)
            }
            return JourneyStage(number: stage.stageNumber, name: stage.name, state: .locked, repsRequired: stage.repsRequired, repsDone: 0)
        }

        let completion = d.rules.completionReps
        return HomeData(
            streak: displayStreak,
            xp: d.stats.xpTotal,
            coins: d.stats.coinsBalance,
            towerName: tower?.name ?? "Your Tower",
            stageNumber: currentStage,
            totalStages: max(stages.count, 1),
            stageName: stageName,
            repsIntoStage: repsIntoStage,
            stageTarget: stageTarget,
            sets: 3,
            repsPerSet: max(completion / 3, 1),
            estimatedMinutes: 5,
            xpPerWorkout: d.rules.xpPerCompleted,
            rewardName: "Stone",
            journey: journey,
            isAllComplete: isAllComplete
        )
    }

    var towers: [Tower] {
        guard let d = dashboard else { return [] }
        let ordered = d.towers.sorted { $0.sortOrder < $1.sortOrder }
        return ordered.enumerated().map { index, definition in
            let stages = d.stages.filter { $0.towerId == definition.id }.sorted { $0.stageNumber < $1.stageNumber }
            let totalReps = stages.reduce(0) { $0 + $1.repsRequired }
            let row = d.progress.first { $0.towerId == definition.id }

            let status: TowerStatus
            let progress: Double
            let currentStage: Int
            var stageFraction: Double = 0
            switch row?.status {
            case "completed":
                status = .completed
                progress = 1
                currentStage = stages.count
            case "in_progress":
                status = .inProgress
                let done = stages.filter { $0.stageNumber < (row?.currentStage ?? 1) }.reduce(0) { $0 + $1.repsRequired }
                    + (row?.repsIntoStage ?? 0)
                progress = totalReps == 0 ? 0 : min(Double(done) / Double(totalReps), 1)
                currentStage = row?.currentStage ?? 1
                if let row, row.stageTarget > 0 {
                    stageFraction = min(max(Double(row.repsIntoStage) / Double(row.stageTarget), 0), 1)
                }
            default:
                status = .locked
                progress = 0
                currentStage = 0
            }

            return Tower(
                id: definition.id,
                name: definition.name,
                status: status,
                currentStage: currentStage,
                totalStages: stages.count,
                totalReps: totalReps,
                progress: progress,
                stageFraction: stageFraction,
                unlockedAfter: index > 0 ? ordered[index - 1].name : nil
            )
        }
    }

    // MARK: - Profile editing

    /// Saves the display name and, if changed, uploads or removes the photo.
    func updateProfile(name: String, photo: Data?, photoChanged: Bool) async throws {
        guard let profile = dashboard?.profile else { return }
        let folder = profile.id.uuidString.lowercased()
        let oldPath = profile.avatarPath
        var newPath = oldPath
        var newAvatarData = avatarData
        let avatars = Backend.client.storage.from("avatars")

        if photoChanged {
            if let photo, let jpeg = Self.prepareAvatar(photo) {
                let path = "\(folder)/avatar-\(Int(Date().timeIntervalSince1970)).jpg"
                try await avatars.upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))
                newPath = path
                newAvatarData = jpeg
            } else {
                newPath = nil
                newAvatarData = nil
            }
        }

        try await Backend.client
            .from("profiles")
            .update(ProfileUpdate(displayName: name, avatarPath: newPath))
            .eq("id", value: folder)
            .execute()

        if photoChanged, let oldPath, oldPath != newPath {
            _ = try? await avatars.remove(paths: [oldPath])
        }
        avatarData = newAvatarData
        loadedAvatarPath = newPath
        await load()
    }

    /// Downscales to 512 px and encodes as JPEG for the private avatars bucket.
    private static func prepareAvatar(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 512
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}
