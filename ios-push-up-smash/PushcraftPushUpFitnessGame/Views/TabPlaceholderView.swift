import SwiftUI

/// Plain placeholder page: dark canvas with a small centered label.
/// Each section gets its real layout in a later task.
struct TabPlaceholderView: View {
    let title: String

    var body: some View {
        Color.black
            .overlay {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .ignoresSafeArea()
    }
}

#Preview {
    TabPlaceholderView(title: "Home")
}
