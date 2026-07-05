import Foundation
import Combine

final class Store: ObservableObject {
    @Published var favourites: Set<String> = []
    @Published var playlists: [Playlist] = []
    @Published var themeKey: String = "blue"
    @Published var wheelStyle: String = "large"       // small-top | small-mid | small-bottom | large
    @Published var symbolsOn: Bool = true
    @Published var hapticsOn: Bool = true
    @Published var clickOn: Bool = false
    @Published var idleTimeout: Int = 30              // seconds until returning to Now Playing; 0 = never
    @Published var holdPlayAction: String = "screen"  // screen | lock

    private let defaults = UserDefaults.standard

    init() { load() }

    // Favourites
    func isFavourite(_ path: String) -> Bool { favourites.contains(path) }
    func toggleFavourite(_ path: String) {
        if favourites.contains(path) { favourites.remove(path) } else { favourites.insert(path) }
        save()
    }

    // Playlists
    func isMember(_ path: String, playlistIndex idx: Int) -> Bool {
        playlists.indices.contains(idx) && playlists[idx].trackPaths.contains(path)
    }
    func toggleMember(_ path: String, playlistIndex idx: Int) {
        guard playlists.indices.contains(idx) else { return }
        if let i = playlists[idx].trackPaths.firstIndex(of: path) {
            playlists[idx].trackPaths.remove(at: i)
        } else {
            playlists[idx].trackPaths.append(path)
        }
        save()
    }
    func addToPlaylist(_ path: String, playlistIndex idx: Int) {
        guard playlists.indices.contains(idx) else { return }
        if !playlists[idx].trackPaths.contains(path) { playlists[idx].trackPaths.append(path) }
        save()
    }
    func createPlaylist(name: String, initial: [String] = []) {
        playlists.append(Playlist(name: name, trackPaths: initial))
        save()
    }

    // Settings
    func setTheme(_ key: String) { themeKey = key; save() }
    func setWheel(_ style: String) { wheelStyle = style; save() }
    func toggleSymbols() { symbolsOn.toggle(); save() }
    func toggleHaptics() { hapticsOn.toggle(); save() }
    func toggleClick() { clickOn.toggle(); save() }
    func setIdle(_ seconds: Int) { idleTimeout = seconds; save() }
    func setHoldPlay(_ action: String) { holdPlayAction = action; save() }

    private func save() {
        defaults.set(Array(favourites), forKey: "cw_favourites")
        if let data = try? JSONEncoder().encode(playlists) { defaults.set(data, forKey: "cw_playlists") }
        defaults.set(themeKey, forKey: "cw_theme")
        defaults.set(wheelStyle, forKey: "cw_wheel")
        defaults.set(symbolsOn, forKey: "cw_symbols")
        defaults.set(hapticsOn, forKey: "cw_haptics")
        defaults.set(clickOn, forKey: "cw_click")
        defaults.set(idleTimeout, forKey: "cw_idle")
        defaults.set(holdPlayAction, forKey: "cw_holdplay")
    }

    private func load() {
        favourites = Set(defaults.stringArray(forKey: "cw_favourites") ?? [])
        if let data = defaults.data(forKey: "cw_playlists"),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = decoded
        }
        themeKey = defaults.string(forKey: "cw_theme") ?? "blue"
        wheelStyle = defaults.string(forKey: "cw_wheel") ?? "large"
        symbolsOn = (defaults.object(forKey: "cw_symbols") as? Bool) ?? true
        hapticsOn = (defaults.object(forKey: "cw_haptics") as? Bool) ?? true
        clickOn = (defaults.object(forKey: "cw_click") as? Bool) ?? false
        idleTimeout = (defaults.object(forKey: "cw_idle") as? Int) ?? 30
        holdPlayAction = defaults.string(forKey: "cw_holdplay") ?? "screen"
    }
}
