import SwiftUI

@main
struct ClickWheelApp: App {
    @StateObject private var player = Player()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .preferredColorScheme(.light)
        }
    }
}
