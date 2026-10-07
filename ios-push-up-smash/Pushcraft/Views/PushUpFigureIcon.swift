import SwiftUI

/// Body of a plank/push-up figure (no SF Symbol exists), drawn in a unit square.
private struct PushUpFigureBody: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Feet → hips → shoulders (plank line)
        p.move(to: CGPoint(x: 0.04, y: 0.62))
        p.addLine(to: CGPoint(x: 0.30, y: 0.56))
        p.addLine(to: CGPoint(x: 0.72, y: 0.44))
        // Supporting arm down to the floor
        p.addLine(to: CGPoint(x: 0.64, y: 0.86))
        return p
    }
}

/// Push-up figure glyph used on the Total push-ups stat card.
struct PushUpFigureIcon: View {
    var color: Color = Color(hex: 0xAFC3E8)

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack {
                PushUpFigureBody()
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: s.width * 0.15,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                Circle()
                    .fill(color)
                    .frame(width: s.width * 0.24, height: s.width * 0.24)
                    .position(x: s.width * 0.86, y: s.height * 0.28)
            }
        }
        .aspectRatio(1.35, contentMode: .fit)
    }
}

#Preview {
    PushUpFigureIcon()
        .frame(width: 40, height: 40)
        .padding()
        .background(Color(hex: 0x0B1426))
}
