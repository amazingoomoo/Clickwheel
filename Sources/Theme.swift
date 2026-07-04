import SwiftUI

struct AppTheme {
    let bg: Color
    let fg: Color
    let muted: Color
    let selBg: Color
    let selFg: Color
    let wheel: Color
    let wheelC: Color
    let wheelLabel: Color
    let accent: Color
    let divider: Color
    let isDark: Bool
}

enum Themes {
    static let order = ["light", "dark", "auto", "tarot", "egypt", "flamingo", "emerald", "cyber", "yellow", "blue"]
    static let labels: [String: String] = [
        "light": "Light", "dark": "Dark", "auto": "Auto", "tarot": "Tarot", "egypt": "Egypt",
        "flamingo": "Flamingo", "emerald": "Emerald City", "cyber": "Cyber", "yellow": "Yellow",
        "blue": "Dark Blue (12 mini)"
    ]

    static func hex(_ v: UInt, _ dark: Bool = true) -> Color {
        Color(red: Double((v >> 16) & 0xff) / 255.0,
              green: Double((v >> 8) & 0xff) / 255.0,
              blue: Double(v & 0xff) / 255.0)
    }

    static func resolve(_ key: String, systemDark: Bool) -> AppTheme {
        let k = (key == "auto") ? (systemDark ? "dark" : "light") : key
        return palettes[k] ?? palettes["dark"]!
    }

    static let palettes: [String: AppTheme] = [
        "light":    AppTheme(bg: hex(0xf4f4f7), fg: hex(0x1a1a1f), muted: hex(0x6a6a76), selBg: hex(0x3a5bff), selFg: .white, wheel: hex(0xffffff), wheelC: hex(0xe9e9f1), wheelLabel: hex(0x6a6a76), accent: hex(0x3a5bff), divider: hex(0xdadae2), isDark: false),
        "dark":     AppTheme(bg: hex(0x1e1e24), fg: hex(0xe6e6ea), muted: hex(0x9a9aa6), selBg: hex(0x6c7bff), selFg: .white, wheel: hex(0x26262e), wheelC: hex(0x3a3a46), wheelLabel: hex(0x9a9aa6), accent: hex(0x6c7bff), divider: hex(0x33333c), isDark: true),
        "tarot":    AppTheme(bg: hex(0x1a1230), fg: hex(0xf0e6d2), muted: hex(0xb6a3d8), selBg: hex(0xd4af37), selFg: hex(0x1a1230), wheel: hex(0x241640), wheelC: hex(0x3a2560), wheelLabel: hex(0xb6a3d8), accent: hex(0xd4af37), divider: hex(0x3a2560), isDark: true),
        "egypt":    AppTheme(bg: hex(0xe3d2a6), fg: hex(0x33291a), muted: hex(0x7c6a45), selBg: hex(0xb06a34), selFg: .white, wheel: hex(0xefe4c7), wheelC: hex(0xd8c69b), wheelLabel: hex(0x7c6a45), accent: hex(0xb06a34), divider: hex(0xcab588), isDark: false),
        "flamingo": AppTheme(bg: hex(0xf9d0dc), fg: hex(0x4a1f2e), muted: hex(0x9c6678), selBg: hex(0xe84d86), selFg: .white, wheel: hex(0xfde4ec), wheelC: hex(0xf5c5d5), wheelLabel: hex(0x9c6678), accent: hex(0xe84d86), divider: hex(0xeca7bb), isDark: false),
        "emerald":  AppTheme(bg: hex(0x0f2a1d), fg: hex(0xeaf6ec), muted: hex(0x8fc4a3), selBg: hex(0x2ee08a), selFg: hex(0x0f2a1d), wheel: hex(0x17402b), wheelC: hex(0x1d5538), wheelLabel: hex(0x8fc4a3), accent: hex(0x2ee08a), divider: hex(0x246b45), isDark: true),
        "cyber":    AppTheme(bg: hex(0x0a0f1e), fg: hex(0xcfe9ff), muted: hex(0x5f80a8), selBg: hex(0x29c4ff), selFg: hex(0x0a0f1e), wheel: hex(0x101a30), wheelC: hex(0x16344f), wheelLabel: hex(0x5f80a8), accent: hex(0x29c4ff), divider: hex(0x1d3a5f), isDark: true),
        "yellow":   AppTheme(bg: hex(0x131209), fg: hex(0xf7f2e4), muted: hex(0x9a927a), selBg: hex(0xf5c518), selFg: hex(0x151206), wheel: hex(0x1f1c11), wheelC: hex(0x282318), wheelLabel: hex(0x8f8869), accent: hex(0xf5c518), divider: hex(0x2a2617), isDark: true),
        "blue":     AppTheme(bg: hex(0x132033), fg: hex(0xeaf0f7), muted: hex(0x7f92ab), selBg: hex(0x4f8fd6), selFg: .white, wheel: hex(0x1b2c44), wheelC: hex(0x223651), wheelLabel: hex(0x6f83a0), accent: hex(0x5b9bd8), divider: hex(0x26405f), isDark: true)
    ]
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = Themes.palettes["blue"]!
}
extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

let favouriteGold = Color(red: 0.96, green: 0.71, blue: 0.0)
