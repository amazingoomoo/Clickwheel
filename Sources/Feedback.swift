import UIKit
import AudioToolbox

enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static var lastClick: TimeInterval = 0
    // Cap the click at ~12 per second so fast scrolling can't stack/overlap them.
    private static let minClickInterval: TimeInterval = 1.0 / 12.0

    // Light tick for scrolling and taps.
    static func tick(haptic: Bool, click: Bool) {
        if haptic {
            selection.selectionChanged()
            selection.prepare()
        }
        if click {
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastClick >= minClickInterval {
                lastClick = now
                AudioServicesPlaySystemSound(1104)
            }
        }
    }

    // Longer, deeper feedback for holds.
    static func hold(haptic: Bool, click: Bool) {
        if haptic {
            heavy.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                heavy.impactOccurred(intensity: 0.85)
            }
            heavy.prepare()
        }
        if click {
            AudioServicesPlaySystemSound(1104)
        }
    }
}
