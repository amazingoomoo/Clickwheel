import UIKit
import AudioToolbox

enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static var lastClick: TimeInterval = 0
    // Cap the click at ~12 per second so fast scrolling can't stack/overlap them.
    private static let minClickInterval: TimeInterval = 1.0 / 12.0

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
}
