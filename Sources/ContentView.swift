import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: Player

    enum Screen {
        case menu
        case songs
        case nowPlaying
    }

    @State private var screens: [Screen] = [.menu]
    @State private var menuSelection = 0
    @State private var songSelection = 0

    private let menuItems = ["Music", "Shuffle All", "Now Playing"]

    private var current: Screen { screens.last ?? .menu }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.deskTop, Theme.deskBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            device
                .frame(maxWidth: 300)
                .padding(.horizontal, 22)
        }
    }

    // MARK: - Device chrome

    private var device: some View {
        VStack(spacing: 20) {
            screenContainer
            ClickWheel(
                onScrollUp: scrollUp,
                onScrollDown: scrollDown,
                onMenu: menuBack,
                onSelect: select,
                onPrev: { player.previous() },
                onNext: { player.next() },
                onPlayPause: { player.togglePlayPause() }
            )
            .frame(width: 208, height: 208)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.bezelTop, Theme.bezelBottom],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 14)
        )
    }

    private var screenContainer: some View {
        screenContent
            .frame(height: 208)
            .frame(maxWidth: .infinity)
            .background(Theme.screenBg)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var screenContent: some View {
        switch current {
        case .menu:
            MenuScreen(items: menuItems, selection: menuSelection)
        case .songs:
            SongScreen(tracks: player.tracks, selection: songSelection)
        case .nowPlaying:
            NowPlayingScreen()
        }
    }

    // MARK: - Wheel actions

    private func scrollUp() {
        switch current {
        case .menu:
            menuSelection = max(0, menuSelection - 1)
        case .songs:
            if !player.tracks.isEmpty {
                songSelection = max(0, songSelection - 1)
            }
        case .nowPlaying:
            player.scrub(by: -5)
        }
    }

    private func scrollDown() {
        switch current {
        case .menu:
            menuSelection = min(menuItems.count - 1, menuSelection + 1)
        case .songs:
            if !player.tracks.isEmpty {
                songSelection = min(player.tracks.count - 1, songSelection + 1)
            }
        case .nowPlaying:
            player.scrub(by: 5)
        }
    }

    private func menuBack() {
        if screens.count > 1 {
            screens.removeLast()
        }
    }

    private func select() {
        switch current {
        case .menu:
            handleMenuSelection()
        case .songs:
            if player.tracks.indices.contains(songSelection) {
                player.play(at: songSelection)
                screens.append(.nowPlaying)
            }
        case .nowPlaying:
            player.togglePlayPause()
        }
    }

    private func handleMenuSelection() {
        switch menuSelection {
        case 0: // Music
            songSelection = 0
            screens.append(.songs)
        case 1: // Shuffle All
            guard !player.tracks.isEmpty else { return }
            player.shuffle = true
            player.play(at: Int.random(in: 0..<player.tracks.count))
            screens.append(.nowPlaying)
        case 2: // Now Playing
            if player.currentTrack != nil {
                screens.append(.nowPlaying)
            }
        default:
            break
        }
    }
}
