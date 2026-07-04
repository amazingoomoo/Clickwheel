import SwiftUI
import MediaPlayer
import AVFoundation

final class SystemVolume {
    static let shared = SystemVolume()
    let volumeView = MPVolumeView(frame: CGRect(x: -4000, y: -4000, width: 1, height: 1))

    private var slider: UISlider? {
        volumeView.subviews.compactMap { $0 as? UISlider }.first
    }

    var current: Float { AVAudioSession.sharedInstance().outputVolume }

    func set(_ value: Float) {
        let clamped = max(0, min(1, value))
        let s = slider
        DispatchQueue.main.async {
            s?.value = clamped
        }
    }
}

// Mounting this (even at 1x1, off screen) enables volume control and hides the system HUD.
struct VolumeHost: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView { SystemVolume.shared.volumeView }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
