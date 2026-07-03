import SwiftUI

enum Theme {
    // Device body
    static let bezelTop = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let bezelBottom = Color(red: 0.82, green: 0.84, blue: 0.88)

    // Screen
    static let screenBg = Color(red: 0.93, green: 0.945, blue: 0.96)

    // Title bar (blue gradient)
    static let barTop = Color(red: 0.66, green: 0.72, blue: 0.82)
    static let barBottom = Color(red: 0.40, green: 0.48, blue: 0.60)

    // Selection highlight (blue gradient)
    static let selTop = Color(red: 0.38, green: 0.60, blue: 0.88)
    static let selBottom = Color(red: 0.16, green: 0.40, blue: 0.74)

    // Text
    static let ink = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let inkSoft = Color(red: 0.42, green: 0.45, blue: 0.50)

    // Click wheel
    static let wheelTop = Color(red: 0.94, green: 0.95, blue: 0.96)
    static let wheelBottom = Color(red: 0.80, green: 0.82, blue: 0.85)
    static let centerTop = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let centerBottom = Color(red: 0.86, green: 0.88, blue: 0.90)

    static let accent = Color(red: 0.16, green: 0.40, blue: 0.74)

    // Backdrop behind the device
    static let deskTop = Color(white: 0.16)
    static let deskBottom = Color(white: 0.06)
}
