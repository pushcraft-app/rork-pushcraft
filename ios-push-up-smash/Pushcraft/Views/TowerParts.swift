import SwiftUI

/// Cut-out stage parts and traced outlines for one tower, decoded from
/// `tower_parts.json`. All coordinates are normalized to the 2:3 tower canvas.
nonisolated struct TowerPartsEntry: Decodable, Sendable {
    /// Closed contours tracing the whole finished tower.
    let silhouette: [[[Double]]]
    /// Stage number ("1"..."9") → closed contours tracing that part.
    let parts: [String: [[[Double]]]]
    /// Stage number → [x, y, width, height] of the part's image in the canvas.
    let rects: [String: [Double]]
}

/// Library of the 45 tower parts (5 towers × 9 stages). Each tower's parts
/// reassemble its original artwork exactly.
enum TowerParts {
    static let stageCount = 9

    private static let library: [String: TowerPartsEntry] = load()

    static func entry(for key: String) -> TowerPartsEntry? { library[key] }

    static func imageName(key: String, stage: Int) -> String { "tower_\(key)_part\(stage)" }

    /// The part's placement inside the canvas, normalized 0...1.
    static func rect(key: String, stage: Int) -> CGRect? {
        guard let r = library[key]?.rects[String(stage)], r.count == 4 else { return nil }
        return CGRect(x: r[0], y: r[1], width: r[2], height: r[3])
    }

    private static func load() -> [String: TowerPartsEntry] {
        guard let url = Bundle.main.url(forResource: "tower_parts", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("TowerParts: tower_parts.json missing from bundle")
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: TowerPartsEntry].self, from: data)
        } catch {
            print("TowerParts: failed to decode parts library")
            return [:]
        }
    }
}

/// One cut-out stage part, placed exactly where it sits in the full tower.
/// Fills the whole canvas so layers can be stacked in a ZStack.
struct TowerPartLayer: View {
    let key: String
    let stage: Int

    var body: some View {
        GeometryReader { geo in
            if let r = TowerParts.rect(key: key, stage: stage) {
                Image(TowerParts.imageName(key: key, stage: stage))
                    .resizable()
                    .frame(width: r.width * geo.size.width, height: r.height * geo.size.height)
                    .position(x: r.midX * geo.size.width, y: r.midY * geo.size.height)
            }
        }
        .allowsHitTesting(false)
    }
}

enum TowerOutlineKind: Equatable {
    case silhouette
    case part(Int)
}

/// Dashed ivory outline tracing a part's real edge (or the whole tower),
/// with a faint cyan glow so it reads on both night and navy backgrounds.
struct TowerOutlineLayer: View {
    let key: String
    let kind: TowerOutlineKind
    var lineWidth: CGFloat = 1.3
    var intensity: Double = 1

    var body: some View {
        TowerOutlineShape(contours: contours)
            .stroke(
                Theme.ivory.opacity(0.85 * intensity),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: [5, 4])
            )
            .shadow(color: Theme.progressCyan.opacity(0.6 * intensity), radius: 3)
            .allowsHitTesting(false)
    }

    private var contours: [[[Double]]] {
        guard let entry = TowerParts.entry(for: key) else { return [] }
        switch kind {
        case .silhouette: return entry.silhouette
        case .part(let stage): return entry.parts[String(stage)] ?? []
        }
    }
}

struct TowerOutlineShape: Shape {
    let contours: [[[Double]]]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for contour in contours {
            guard let first = contour.first, first.count == 2 else { continue }
            path.move(to: CGPoint(x: rect.minX + first[0] * rect.width, y: rect.minY + first[1] * rect.height))
            for point in contour.dropFirst() where point.count == 2 {
                path.addLine(to: CGPoint(x: rect.minX + point[0] * rect.width, y: rect.minY + point[1] * rect.height))
            }
            path.closeSubpath()
        }
        return path
    }
}

/// Faint filled silhouette of the finished tower with a subtle edge, drawn
/// behind the parts already built so the final shape stays visible while a
/// tower is still growing.
struct TowerSilhouetteLayer: View {
    let key: String
    var intensity: Double = 1

    var body: some View {
        TowerOutlineShape(contours: TowerParts.entry(for: key)?.silhouette ?? [])
            .fill(Color(hex: 0x081120).opacity(0.55 * intensity))
            .overlay {
                TowerOutlineShape(contours: TowerParts.entry(for: key)?.silhouette ?? [])
                    .stroke(Theme.ivory.opacity(0.25 * intensity), lineWidth: 1)
            }
            .allowsHitTesting(false)
    }
}
