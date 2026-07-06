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
    case settings, themeList, wheelList, idleList, lockClockList, brightnessScreen
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
    case idle(Int)
    case lockClock(String)
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
            let start = windowStart(maxRows)
            let end = min(start + maxRows, rows.count)
            let hasMore = end < rows.count
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.fg)
                    .frame(maxWidth: .infinity)
                    .frame(height: headerH)

                ForEach(Array(start..<end), id: \.self) { i in
                    RowView(row: rows[i], selected: i == sel, store: store)
                }
                Spacer(minLength: 0)
            }
            .overlay(alignment: .bottom) {
                if hasMore {
                    ZStack(alignment: .bottom) {
                        LinearGradient(colors: [theme.bg.opacity(0), theme.bg], startPoint: .top, endPoint: .bottom)
                            .frame(height: 68)
                        WideChevron()
                            .stroke(theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .frame(width: 60, height: 14)
                            .padding(.bottom, 9)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func windowStart(_ visible: Int) -> Int {
        if sel < visible { return 0 }
        return min(sel - visible + 1, max(0, rows.count - visible))
    }
}

// A wide, shallow downward chevron used to signal "more below".
struct WideChevron: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

// MARK: - Now Playing

struct NowPlayingScreen: View {
    @Environment(\.appTheme) var theme
    @ObservedObject var player: Player
    let store: Store

    @State private var textOpacity: Double = 1
    @State private var textResetWork: DispatchWorkItem?

    var body: some View {
        GeometryReader { geo in
            let side = max(0, min(geo.size.width, geo.size.height - 34))
            VStack(spacing: 0) {
                artwork(side: side)
                VStack(spacing: 3) {
                    HStack(spacing: 8) {
                        Text(timeString(player.currentTime))
                            .font(.system(size: 9))
                            .foregroundColor(theme.muted)
                        Text(displayText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.fg)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .opacity(textOpacity)
                            .contentShape(Rectangle())
                            .onTapGesture { cycleText() }
                        Text("-" + timeString(max(0, player.duration - player.currentTime)))
                            .font(.system(size: 9))
                            .foregroundColor(theme.muted)
                    }
                    controlRow
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                Spacer(minLength: 0)
            }
        }
    }

    private var displayText: String {
        let t = player.current
        switch player.npTextMode {
        case 1: return (t?.album).flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown Album"
        case 2: return (t?.artist).flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown Artist"
        default: return t?.title ?? "\u{2014}"
        }
    }

    private func cycleText() {
        withAnimation(.easeInOut(duration: 0.18)) { textOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
            player.npTextMode = (player.npTextMode + 1) % 3
            withAnimation(.easeInOut(duration: 0.18)) { textOpacity = 1 }
        }
        scheduleTextReset()
    }

    private func scheduleTextReset() {
        textResetWork?.cancel()
        let work = DispatchWorkItem {
            if player.npTextMode != 0 {
                withAnimation(.easeInOut(duration: 0.18)) { textOpacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
                    player.npTextMode = 0
                    withAnimation(.easeInOut(duration: 0.18)) { textOpacity = 1 }
                }
            }
        }
        textResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
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
        if player.mode == .volume && player.volumeVisible {
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
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.divider)
                    Capsule().fill(theme.accent).frame(width: g.size.width * CGFloat(fraction))
                    if player.mode == .options {
                        Circle().fill(theme.accent)
                            .frame(width: 13, height: 13)
                            .overlay(Circle().stroke(theme.bg, lineWidth: 2))
                            .offset(x: g.size.width * CGFloat(fraction) - 6.5)
                    }
                }
            }
            .frame(height: player.mode == .options ? 8 : 5)
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

// MARK: - Brightness (Settings)

struct BrightnessScreen: View {
    @Environment(\.appTheme) var theme
    let level: CGFloat

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "sun.max.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.accent)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.divider)
                    Capsule().fill(theme.accent).frame(width: g.size.width * max(0, min(1, level)))
                }
            }
            .frame(height: 10)
            .padding(.horizontal, 44)
            Text("\(Int(level * 100))%")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.fg)
            Text("Turn the wheel to adjust")
                .font(.system(size: 11))
                .foregroundColor(theme.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Lock clock (shown while the screen is dimmed)

struct LockClock: View {
    let large: Bool
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if large {
                VStack(spacing: 6) {
                    Text(dateString(now))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text(timeString(now))
                        .font(.system(size: 70, weight: .thin, design: .rounded))
                        .foregroundColor(.white)
                }
            } else {
                Text(timeString(now))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM"; return f.string(from: d)
    }
}
