import AppTrackingTransparency
import Foundation

/// Presents Apple's App Tracking Transparency prompt once per install,
/// at the moment the user leaves the welcome screen. Resolves Guideline
/// 5.1.2(i) for the tracking data declared in the privacy labels; analytics
/// behavior is unchanged either way (Mixpanel uses no advertising identifiers).
enum TrackingPermission {
    /// Shows the system dialog over the current screen when permission is
    /// still undetermined; every other state is a silent no-op, so returning
    /// users and users who already answered never see it again.
    static func requestIfNeeded() {
        Task { @MainActor in
            guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
            // Let the push transition settle — a prompt presented mid-transition
            // can be silently dropped by the system.
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
    }
}
