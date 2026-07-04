import UIKit
import AudioToolbox

enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()

    static func tick(haptic: Bool, click: Bool) {
        if haptic {
            selection.selectionChanged()
            selection.prepare()
        }
        if click {
            AudioServicesPlaySystemSound(1104)
        }
    }
}
