import CoreGraphics
import Foundation

/// One analysed camera frame. Joint points are normalized (0...1) with a top-left origin,
/// in the coordinate space of the already rotated + mirrored video buffer.
nonisolated struct PoseFrame: Sendable {
    let joints: [Joint: CGPoint]
    let imageSize: CGSize
    let timestamp: Double
}

/// Smoothed pose used for drawing the skeleton.
struct DisplayPose: Equatable {
    var joints: [Joint: CGPoint]
    var imageSize: CGSize

    static let empty = DisplayPose(joints: [:], imageSize: .zero)
}

/// Maps normalized buffer points into a view that shows the buffer with aspect-fill,
/// matching `AVLayerVideoGravity.resizeAspectFill`.
nonisolated enum PoseMapper {
    static func map(_ point: CGPoint, imageSize: CGSize, viewSize: CGSize) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGPoint(x: point.x * viewSize.width, y: point.y * viewSize.height)
        }
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGPoint(
            x: (viewSize.width - width) / 2 + point.x * width,
            y: (viewSize.height - height) / 2 + point.y * height
        )
    }
}
