import Vision

/// The 19 body joints reported by Vision's human body pose request.
nonisolated enum Joint: String, CaseIterable, Sendable {
    case nose, leftEye, rightEye, leftEar, rightEar
    case neck, leftShoulder, rightShoulder
    case leftElbow, rightElbow, leftWrist, rightWrist
    case root, leftHip, rightHip
    case leftKnee, rightKnee, leftAnkle, rightAnkle

    var visionName: VNHumanBodyPoseObservation.JointName {
        switch self {
        case .nose: .nose
        case .leftEye: .leftEye
        case .rightEye: .rightEye
        case .leftEar: .leftEar
        case .rightEar: .rightEar
        case .neck: .neck
        case .leftShoulder: .leftShoulder
        case .rightShoulder: .rightShoulder
        case .leftElbow: .leftElbow
        case .rightElbow: .rightElbow
        case .leftWrist: .leftWrist
        case .rightWrist: .rightWrist
        case .root: .root
        case .leftHip: .leftHip
        case .rightHip: .rightHip
        case .leftKnee: .leftKnee
        case .rightKnee: .rightKnee
        case .leftAnkle: .leftAnkle
        case .rightAnkle: .rightAnkle
        }
    }

    var isFace: Bool {
        switch self {
        case .nose, .leftEye, .rightEye, .leftEar, .rightEar: true
        default: false
        }
    }
}
