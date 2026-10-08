import SwiftUI

/// Crisp white stick-figure drawn over the camera feed.
struct SkeletonView: View {
    let pose: DisplayPose

    private static let bones: [(Joint, Joint)] = [
        (.leftShoulder, .rightShoulder),
        (.neck, .nose),
        (.neck, .root),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        Canvas { context, size in
            guard !pose.joints.isEmpty else { return }

            func point(_ joint: Joint) -> CGPoint? {
                pose.joints[joint].map { PoseMapper.map($0, imageSize: pose.imageSize, viewSize: size) }
            }

            var path = Path()
            for (a, b) in Self.bones {
                guard let pa = point(a), let pb = point(b) else { continue }
                path.move(to: pa)
                path.addLine(to: pb)
            }
            let round = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            context.stroke(path, with: .color(.black.opacity(0.3)), style: round)
            context.stroke(
                path,
                with: .color(.white),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )

            for (joint, _) in pose.joints {
                guard let p = point(joint) else { continue }
                let radius: CGFloat = joint.isFace ? 3 : 5.5
                let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)), with: .color(.black.opacity(0.3)))
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }
}
