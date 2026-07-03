import SwiftUI

// MARK: - Shared building blocks

struct TitleBar: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                LinearGradient(
                    colors: [Theme.barTop, Theme.barBottom],
                    startPoint: .top, endPoint: .bottom
                )
            )
    }
}

struct Row: View {
    let text: String
    let selected: Bool
    var chevron: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 14))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(selected ? .white : Theme.inkSoft)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .foregroundColor(selected ? .white : Theme.ink)
        .background(selectionBackground)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if selected {
            LinearGradient(
                colors: [Theme.selTop, Theme.selBottom],
                startPoint: .top, endPoint: .bottom
            )
        } else {
            Color.clear
        }
    }
}

struct EmptyState: View {
    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 26))
                .foregroundColor(Theme.inkSoft)
            Text("No music yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.ink)
            Text("Add songs to the ClickWheel folder\nover USB, then reopen the app.")
                .font(.system(size: 10))
                .foregroundColor(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Menu

struct MenuScreen: View {
    let items: [String]
    let selection: Int

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(text: "iPod")
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Row(text: item, selected: index == selection, chevron: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Songs

struct SongScreen: View {
    let tracks: [Track]
    let selection: Int

    private let visibleRows = 6

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(text: "Songs")
            if tracks.isEmpty {
                EmptyState()
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleIndices, id: \.self) { index in
                        Row(text: tracks[index].displayTitle, selected: index == selection)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var visibleIndices: [Int] {
        let start = windowStart()
        let end = min(start + visibleRows, tracks.count)
        return Array(start..<end)
    }

    private func windowStart() -> Int {
        if selection < visibleRows { return 0 }
        return min(selection - visibleRows + 1, max(0, tracks.count - visibleRows))
    }
}

// MARK: - Now Playing

struct NowPlayingScreen: View {
    @EnvironmentObject var player: Player

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(text: "Now Playing")
            VStack(spacing: 7) {
                artwork
                Text(player.nowPlayingTitle.isEmpty ? "—" : player.nowPlayingTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                if !player.nowPlayingArtist.isEmpty {
                    Text(player.nowPlayingArtist)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.inkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                progress
            }
            .padding(10)
        }
    }

    private var artwork: some View {
        Group {
            if let image = player.nowPlayingArtwork {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [Theme.selTop, Theme.selBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.85))
                )
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .padding(.top, 6)
    }

    private var progress: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.12))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(fraction))
                }
            }
            .frame(height: 5)

            HStack {
                Text(timeString(player.currentTime))
                Spacer()
                Text("-" + timeString(max(0, player.duration - player.currentTime)))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(Theme.inkSoft)
        }
    }

    private var fraction: Double {
        player.duration > 0
            ? min(1, max(0, player.currentTime / player.duration))
            : 0
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(time)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
