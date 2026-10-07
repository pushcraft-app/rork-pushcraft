import SwiftUI

/// Springy press-down feedback for buttons, with a full-strength Light haptic
/// the moment a finger touches down.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticService.ui.tap() }
            }
    }
}
