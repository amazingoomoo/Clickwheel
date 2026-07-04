import SwiftUI

// MARK: - Navigation model

enum Screen: Equatable {
    case main, musicMenu, albums, artists, tracks
    case albumTracks(String)
    case artistTracks(String)
    case favourites, playlists
    case playlistTracks(Int)
    case plEdit(Int)
    case addToPlaylist(String)
    case settings, themeList, wheelList
    case nowPlaying
}

struct NavEntry {
    var screen: Screen
    var sel: Int = 0
    var edit: Int? = nil
}

enum RowTrailing {
    case none
    case checkmark(Bool)
    case value(String)
}

enum WAction {
    case go(Screen, Int?)
    case playFrom
    case shuffle([Track])
    case theme(String)
    case wheel(String)
    case toggleSymbols
    case toggleHaptics
    case toggleClick
    case newPlaylist
    case newPlaylistAdd
    case addToPlaylist(Int)
    case toggleMember(Int, String)
    case none
}

struct WRow {
    var label: String
    var trackPath: String? = nil
    var artKey: String? = nil
    var editPlaylist: Int? = nil
    var trailing: RowTrailing = .none
    var action: WAction
}

// MARK: - Row

struct RowView: View {
    @Environment(\.appTheme) var theme
    let row: WRow
    let selected: Bool
    let store: Store

    var body: some View {
        HStack(spacing: 8) {
            if let key = row.artKey {
                ThumbnailView(path: key)
            }
            Text(row.label)
                .font(.system(size: 14))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            trailingView
        }
        .padding(.horizontal, 16)
        .frame(height: 30)
        .foregroundColor(selected ? theme.selFg : theme.fg)
        .background(selected ? theme.selBg : Color.clear)
    }

    @ViewBuilder private var trailingView: some View {
        if let editIdx = row.editPlaylist, let path = row.trackPath {
            let member = store.isMember(path, playlistIndex: editIdx)
            Image(systemName: member ? "checkmark" : "circle")
                .font(.system(size: 12, weight: member ? .bold : .regular))
                .foregroundColor(selected ? theme.selFg : (member ? theme.accent : theme.muted))
        } else if let path = row.trackPath, store.isFavourite(path) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundColor(selected ? theme.selFg : favouriteGold)
        } else {
            switch row.trailing {
            case .checkmark(let on):
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(selected ? theme.selFg : theme.accent)
                }
            case .value(let text):
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(selected ? theme.selFg : theme.muted)
            case .none:
                EmptyView()
            }
        }
    }
}

// MARK: - List screen

struct ListScreen: View {
    @Environment(\.appTheme) var theme
    let title: String
    let rows: [WRow]
    let sel: Int
    let store: Store

    var body: some View {
        GeometryReader { geo in
            let rowH: CGFloat = 30
            let headerH: CGFloat = 30
            let maxRows = max(1, Int((geo.size.height - headerH) / rowH))
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.fg)
                    .frame(maxWidth: .infinity)
                    .frame(height: headerH)

                let start = windowStart(maxRows)
                let end = min(start + maxRows, rows.count)
                ForEach(Array(start..<end), id: \.self) { i in
                    RowView(row: rows[i], selected: i == sel, store: store)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func windowStart(_ visible: Int) -> Int {
        if sel < visible { return 0 }
        return min(sel - visible + 1, max(0, rows.count - visible))
    }
}

// MARK: - Now Playing

struct NowPlayingScreen: View {
    @Environment(\.appTheme) var theme
    @ObservedObject var player: Player
    let store: Store

    var body: some View {
        GeometryReader { geo in
            let side = max(0, min(geo.size.width, geo.size.height - 34))
            VStack(spacing: 0) {
                artwork(side: side)
                VStack(spacing: 2) {
                    Text(player.current?.title ?? "\u{2014}")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.fg)
                        .lineLimit(1)
                    controlRow
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                Spacer(minLength: 0)
            }
        }
    }

    private func artwork(side: CGFloat) -> some View {
        ZStack {
            if let img = player.artwork {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [theme.accent.opacity(0.85), theme.accent.opacity(0.4)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.85))
                    )
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var controlRow: some View {
        if player.mode == .favourite {
            let on = player.current.map { store.isFavourite($0.relativePath) } ?? false
            Image(systemName: on ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundColor(on ? favouriteGold : theme.muted)
        } else if player.mode == .volume && player.volumeVisible {
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").font(.system(size: 9)).foregroundColor(theme.muted)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.divider)
                        Capsule().fill(theme.accent).frame(width: g.size.width * CGFloat(player.volume))
                    }
                }
                .frame(height: 4)
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 9)).foregroundColor(theme.muted)
            }
            .frame(height: 16)
        } else {
            VStack(spacing: 1) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.divider)
                        Capsule().fill(theme.accent).frame(width: g.size.width * CGFloat(fraction))
                        if player.mode == .scrub {
                            Circle().fill(theme.accent).frame(width: 10, height: 10)
                                .offset(x: g.size.width * CGFloat(fraction) - 5)
                        }
                    }
                }
                .frame(height: player.mode == .scrub ? 6 : 4)
                HStack {
                    Text(timeString(player.currentTime))
                    Spacer()
                    Text("-" + timeString(max(0, player.duration - player.currentTime)))
                }
                .font(.system(size: 8))
                .foregroundColor(theme.muted)
            }
        }
    }

    private var fraction: Double {
        player.duration > 0 ? min(1, max(0, player.currentTime / player.duration)) : 0
    }
    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
