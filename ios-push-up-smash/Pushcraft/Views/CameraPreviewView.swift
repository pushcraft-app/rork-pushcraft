import AVFoundation
import SwiftUI
import UIKit

/// Hosts the sample-buffer layer that shows the exact frames Vision analyses.
struct CameraPreviewView: UIViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.attach(displayLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {}

    final class PreviewHostView: UIView {
        private var hostedLayer: CALayer?

        func attach(_ sublayer: CALayer) {
            backgroundColor = .black
            layer.addSublayer(sublayer)
            hostedLayer = sublayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hostedLayer?.frame = bounds
            CATransaction.commit()
        }
    }
}
