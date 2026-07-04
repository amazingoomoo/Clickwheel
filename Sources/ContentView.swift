import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var library: Library
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme

    @State private var stack: [NavEntry] = [NavEntry(screen: .main)]

    @State private var showNameEntry = false
    @State private var nameText = ""
    @State private var nameCompletion: ((String) -> Void)? = nil
    @FocusState private var nameFocused: Bool

    private var theme: AppTheme { Themes.resolve(store.themeKey, systemDark: colorScheme == .dark) }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let style = store.wheelStyle
            let wheelD: CGFloat = style == "large" ? (W * 0.85).rounded()
                : style == "medium" ? (W * 0.53).rounded()
                : (W * 0.42).rounded()
            let sideGap = (W - wheelD) / 2
            let regionH: CGFloat
            let wheelAlign: Alignment
            if style == "large" {
                regionH = wheelD + sideGap
                wheelAlign = .top
            } else if style == "medium" {
                regionH = max((H * 0.34).rounded(), wheelD + 20)
                wheelAlign = .center
            } else {
                regionH = max((H * 0.30).rounded(), wheelD + 12)
                wheelAlign = style == "small-top" ? .top : (style == "small-bottom" ? .bottom : .center)
            }
            let contentH = max(0, H - regionH)

            ZStack {
                theme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    ZStack {
                        if store.symbolsOn { MotifBackground(themeKey: store.themeKey) }
                        screenContent
                    }
                    .frame(width: W, height: contentH)
                    .clipped()

                    ZStack(alignment: wheelAlign) {
                        Color.clear
                        ClickWheel(
                            diameter: wheelD,
                            onScrollUp: { scroll(-1) },
                            onScrollDown: { scroll(1) },
                            onMenu: { menuBack() },
                            onSelect: { onCenter() },
                            onPrev: { player.previous() },
                            onNext: { player.next() },
                            onPlayPause: { onPlay() },
                            onLongCenter: { onLongCenter() }
                        )
                    }
                    .frame(width: W, height: regionH)
                }

                VolumeHost().frame(width: 1, height: 1).opacity(0.001)

                if showNameEntry { nameOverlay }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .environment(\.appTheme, theme)
        .preferredColorScheme(store.themeKey == "auto" ? nil : (theme.isDark ? .dark : .light))
    }

    // MARK: - Screen content

    @ViewBuilder private var screenContent: some View {
        let entry = stack[stack.count - 1]
        if entry.screen == .nowPlaying {
            NowPlayingScreen(player: player, store: store)
        } else {
            ListScreen(title: title(for: entry), rows: rows(for: entry), sel: entry.sel, store: store)
        }
    }

    private var nameOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Playlist name")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.fg)
                TextField("Name", text: $nameText)
                    .focused($nameFocused)
                    .padding(8)
                    .background(theme.bg)
                    .cornerRadius(8)
                    .foregroundColor(theme.fg)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.divider, lineWidth: 1))
                    .onSubmit { commitName() }
                HStack(spacing: 8) {
                    Button("Cancel") { cancelName() }
                        .foregroundColor(theme.fg)
                        .frame(maxWidth: .infinity).padding(8)
                        .background(theme.divider).cornerRadius(8)
                    Button("Save") { commitName() }
                        .foregroundColor(theme.selFg)
                        .frame(maxWidth: .infinity).padding(8)
                        .background(theme.accent).cornerRadius(8)
                }
            }
            .padding(16)
            .frame(width: 240)
            .background(theme.wheel)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.divider, lineWidth: 1))
        }
    }

    // MARK: - Titles

    private func title(for e: NavEntry) -> String {
        switch e.screen {
        case .main: return "ClickWheel"
        case .musicMenu: return "Music"
        case .albums: return e.edit != nil ? "Add: Albums" : "Albums"
        case .albumTracks(let a): return a
        case .artists: return e.edit != nil ? "Add: Artists" : "Artists"
        case .artistTracks(let a): return a
        case .tracks: return e.edit != nil ? "Add: Tracks" : "Tracks"
        case .favourites: return "Favourites"
        case .playlists: return "Playlists"
        case .playlistTracks(let i): return store.playlists.indices.contains(i) ? store.playlists[i].name : "Playlist"
        case .plEdit(let i): return store.playlists.indices.contains(i) ? "Add to " + store.playlists[i].name : "Add"
        case .addToPlaylist: return "Add to Playlist"
        case .settings: return "Settings"
        case .themeList: return "Theme"
        case .wheelList: return "Wheel"
        case .nowPlaying: return "Now Playing"
        }
    }

    // MARK: - Rows

    private func trackRow(_ t: Track, edit: Int?) -> WRow {
        if let e = edit {
            return WRow(label: t.title, trackPath: t.relativePath, editPlaylist: e, action: .toggleMember(e, t.relativePath))
        } else {
            return WRow(label: t.title, trackPath: t.relativePath, action: .playFrom)
        }
    }

    private func rows(for e: NavEntry) -> [WRow] {
        switch e.screen {
        case .main:
            return [
                WRow(label: "Music", action: .go(.musicMenu, nil)),
                WRow(label: "Shuffle All", action: .shuffle(library.tracks)),
                WRow(label: "Favourites", action: .go(.favourites, nil)),
                WRow(label: "Playlists", action: .go(.playlists, nil)),
                WRow(label: "Settings", action: .go(.settings, nil))
            ]
        case .musicMenu:
            return [
                WRow(label: "Albums", action: .go(.albums, nil)),
                WRow(label: "Artists", action: .go(.artists, nil)),
                WRow(label: "Tracks", action: .go(.tracks, nil))
            ]
        case .albums:
            var r: [WRow] = []
            if e.edit == nil { r.append(WRow(label: "Shuffle All", action: .shuffle(library.tracks))) }
            for a in library.albums { r.append(WRow(label: a, action: .go(.albumTracks(a), e.edit))) }
            return r
        case .albumTracks(let album):
            let ts = library.tracksInAlbum(album)
            var r: [WRow] = []
            if e.edit == nil { r.append(WRow(label: "Shuffle All", action: .shuffle(ts))) }
            for t in ts { r.append(trackRow(t, edit: e.edit)) }
            return r
        case .artists:
            var r: [WRow] = []
            if e.edit == nil { r.append(WRow(label: "Shuffle All", action: .shuffle(library.tracks))) }
            for a in library.artists { r.append(WRow(label: a, action: .go(.artistTracks(a), e.edit))) }
            return r
        case .artistTracks(let artist):
            let ts = library.tracksByArtist(artist)
            var r: [WRow] = []
            if e.edit == nil { r.append(WRow(label: "Shuffle All", action: .shuffle(ts))) }
            for t in ts { r.append(trackRow(t, edit: e.edit)) }
            return r
        case .tracks:
            var r: [WRow] = []
            if e.edit == nil { r.append(WRow(label: "Shuffle All", action: .shuffle(library.tracks))) }
            for t in library.tracks { r.append(trackRow(t, edit: e.edit)) }
            return r
        case .favourites:
            let favs = library.tracks.filter { store.isFavourite($0.relativePath) }
            var r: [WRow] = [WRow(label: "Shuffle All", action: .shuffle(favs))]
            if favs.isEmpty {
                r.append(WRow(label: "No favourites yet", action: .none))
            } else {
                for t in favs { r.append(trackRow(t, edit: nil)) }
            }
            return r
        case .playlists:
            var r: [WRow] = []
            for (i, p) in store.playlists.enumerated() {
                r.append(WRow(label: p.name, action: .go(.playlistTracks(i), nil)))
            }
            r.append(WRow(label: "+ New Playlist\u{2026}", action: .newPlaylist))
            return r
        case .playlistTracks(let idx):
            guard store.playlists.indices.contains(idx) else { return [] }
            let ts = store.playlists[idx].trackPaths.compactMap { library.track(withPath: $0) }
            var r: [WRow] = [
                WRow(label: "Edit", action: .go(.plEdit(idx), nil)),
                WRow(label: "Shuffle All", action: .shuffle(ts))
            ]
            for t in ts { r.append(trackRow(t, edit: nil)) }
            return r
        case .plEdit(let idx):
            return [
                WRow(label: "Tracks", action: .go(.tracks, idx)),
                WRow(label: "Albums", action: .go(.albums, idx)),
                WRow(label: "Artists", action: .go(.artists, idx))
            ]
        case .addToPlaylist:
            var r: [WRow] = []
            for (i, p) in store.playlists.enumerated() {
                r.append(WRow(label: p.name, action: .addToPlaylist(i)))
            }
            r.append(WRow(label: "+ New Playlist\u{2026}", action: .newPlaylistAdd))
            return r
        case .settings:
            return [
                WRow(label: "Theme", action: .go(.themeList, nil)),
                WRow(label: "Wheel", action: .go(.wheelList, nil)),
                WRow(label: "Background Symbols", trailing: .value(store.symbolsOn ? "On" : "Off"), action: .toggleSymbols),
                WRow(label: "Haptics", trailing: .value(store.hapticsOn ? "On" : "Off"), action: .toggleHaptics),
                WRow(label: "Wheel Click", trailing: .value(store.clickOn ? "On" : "Off"), action: .toggleClick)
            ]
        case .themeList:
            return Themes.order.map { key in
                WRow(label: Themes.labels[key] ?? key, trailing: .checkmark(key == store.themeKey), action: .theme(key))
            }
        case .wheelList:
            let opts = [("small-top", "Small (top)"), ("small-mid", "Small (middle)"), ("small-bottom", "Small (bottom)"), ("medium", "Medium"), ("large", "Large")]
            return opts.map { WRow(label: $0.1, trailing: .checkmark($0.0 == store.wheelStyle), action: .wheel($0.0)) }
        case .nowPlaying:
            return []
        }
    }

    // MARK: - Wheel dispatch

    private func scroll(_ dir: Int) {
        Haptics.tick(haptic: store.hapticsOn, click: store.clickOn)
        let entry = stack[stack.count - 1]
        if entry.screen == .nowPlaying {
            switch player.mode {
            case .volume: player.nudgeVolume(Float(dir) * 0.06)
            case .scrub: player.scrub(by: Double(dir) * 5)
            case .favourite: break
            }
        } else {
            let count = rows(for: entry).count
            var s = entry.sel + dir
            if s < 0 { s = 0 }
            if s > count - 1 { s = max(0, count - 1) }
            stack[stack.count - 1].sel = s
        }
    }

    private func onCenter() {
        if stack.last?.screen == .nowPlaying { player.cycleMode() } else { select() }
    }

    private func onPlay() {
        if stack.last?.screen == .nowPlaying && player.mode == .favourite {
            if let p = player.current?.relativePath { store.toggleFavourite(p) }
        } else {
            player.togglePlayPause()
        }
    }

    private func onLongCenter() {
        let entry = stack[stack.count - 1]
        var path: String? = nil
        if entry.screen == .nowPlaying {
            path = player.current?.relativePath
        } else {
            let rs = rows(for: entry)
            if rs.indices.contains(entry.sel) { path = rs[entry.sel].trackPath }
        }
        if let p = path { stack.append(NavEntry(screen: .addToPlaylist(p))) }
    }

    private func menuBack() { popTop() }

    private func pushNowPlaying() {
        if stack.last?.screen != .nowPlaying { stack.append(NavEntry(screen: .nowPlaying)) }
    }
    private func popTop() {
        if stack.count > 1 { stack.removeLast() }
    }

    private func select() {
        let entry = stack[stack.count - 1]
        let rs = rows(for: entry)
        guard rs.indices.contains(entry.sel) else { return }
        let row = rs[entry.sel]
        switch row.action {
        case .none:
            break
        case .go(let screen, let edit):
            stack.append(NavEntry(screen: screen, edit: edit))
        case .shuffle(let tracks):
            if !tracks.isEmpty { player.shufflePlay(tracks); pushNowPlaying() }
        case .theme(let key):
            store.setTheme(key)
        case .wheel(let style):
            store.setWheel(style)
        case .toggleSymbols:
            store.toggleSymbols()
        case .toggleHaptics:
            store.toggleHaptics()
        case .toggleClick:
            store.toggleClick()
        case .newPlaylist:
            promptName { store.createPlaylist(name: $0) }
        case .newPlaylistAdd:
            if case .addToPlaylist(let path) = entry.screen {
                promptName { store.createPlaylist(name: $0, initial: [path]); popTop() }
            }
        case .addToPlaylist(let idx):
            if case .addToPlaylist(let path) = entry.screen {
                store.addToPlaylist(path, playlistIndex: idx)
                popTop()
            }
        case .toggleMember(let idx, let path):
            store.toggleMember(path, playlistIndex: idx)
        case .playFrom:
            let paths = rs.compactMap { $0.trackPath }
            let tracks = paths.compactMap { library.track(withPath: $0) }
            if let selPath = row.trackPath, let ti = tracks.firstIndex(where: { $0.relativePath == selPath }) {
                player.playQueue(tracks, startAt: ti)
                pushNowPlaying()
            }
        }
    }

    // MARK: - Name entry

    private func promptName(_ completion: @escaping (String) -> Void) {
        nameText = "New Playlist"
        nameCompletion = completion
        showNameEntry = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { nameFocused = true }
    }
    private func cancelName() {
        showNameEntry = false
        nameCompletion = nil
        nameFocused = false
    }
    private func commitName() {
        let name = nameText.trimmingCharacters(in: .whitespaces)
        let cb = nameCompletion
        showNameEntry = false
        nameCompletion = nil
        nameFocused = false
        if !name.isEmpty { cb?(name) }
    }
}
