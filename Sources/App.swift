import SwiftUI

@main
struct ClickWheelApp: App {
    @StateObject private var player = Player()
    @StateObject private var library = Library()
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .environmentObject(library)
                .environmentObject(store)
        }
    }
}
