import Foundation
import Combine
import AVFoundation

struct CachedMeta: Codable {
    var mtime: Double
    var title: String
    var artist: String
    var album: String
}

final class Library: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var albums: [String] = []
    @Published var artists: [String] = []
    var albumArtKey: [String: String] = [:]
    var artistArtKey: [String: String] = [:]

    private let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "alac", "wav", "aif", "aiff", "caf", "m4b", "flac"]

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static let musicFolderPath = "/var/mobile/Media/ClickWheel"
    static let extraMusicPaths = [
        "/var/mobile/Media/iTunes_Control/Music",
        "/var/mobile/Media/Downloads"
    ]
    private static let cachePath = "/var/mobile/Media/ClickWheel/.cw_metacache.json"

    private var metaCache: [String: CachedMeta] = [:]

    private struct FileInfo {
        let url: URL
        let path: String
        let mtime: Double
    }

    init() { scan() }

    func track(withPath path: String) -> Track? { tracks.first { $0.relativePath == path } }
    func tracksInAlbum(_ album: String) -> [Track] { tracks.filter { $0.album == album } }
    func tracksByArtist(_ artist: String) -> [Track] {
        tracks.filter { $0.artist == artist }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func scan() {
        let fm = FileManager.default
        let external = URL(fileURLWithPath: Library.musicFolderPath, isDirectory: true)
        try? fm.createDirectory(at: external, withIntermediateDirectories: true)

        var roots: [URL] = [external]
        for p in Library.extraMusicPaths where fm.fileExists(atPath: p) {
            roots.append(URL(fileURLWithPath: p, isDirectory: true))
        }
        roots.append(Library.documentsURL)

        loadCache()
        let cache = metaCache

        var files: [FileInfo] = []
        var seen = Set<String>()
        for root in roots {
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for case let url as URL in enumerator where audioExtensions.contains(url.pathExtension.lowercased()) {
                if seen.insert(url.path).inserted {
                    let mtime = ((try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate)?.timeIntervalSince1970 ?? 0
                    files.append(FileInfo(url: url, path: url.path, mtime: mtime))
                }
            }
        }

        var built: [Track] = []
        var toRead: [FileInfo] = []
        for f in files {
            if let c = cache[f.path], abs(c.mtime - f.mtime) < 1 {
                built.append(Track(url: f.url, relativePath: f.path, title: c.title, artist: c.artist, album: c.album))
            } else {
                built.append(Track(url: f.url, relativePath: f.path, title: Library.cleanName(f.url), artist: "", album: "Unknown Album"))
                toRead.append(f)
            }
        }
        built.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        DispatchQueue.main.async {
            self.tracks = built
            self.rebuildGroups()
        }

        if !toRead.isEmpty { readMetadata(for: toRead) }
    }

    private func readMetadata(for files: [FileInfo]) {
        DispatchQueue.global(qos: .userInitiated).async {
            var pending: [String: CachedMeta] = [:]
            var processed = 0
            for f in files {
                autoreleasepool {
                    let asset = AVURLAsset(url: f.url)
                    var title = Library.cleanName(f.url)
                    var artist = ""
                    var album = "Unknown Album"
                    for item in asset.commonMetadata {
                        guard let key = item.commonKey else { continue }
                        switch key {
                        case .commonKeyTitle:
                            if let s = item.stringValue, !s.isEmpty { title = s }
                        case .commonKeyArtist:
                            if let s = item.stringValue, !s.isEmpty { artist = s }
                        case .commonKeyAlbumName:
                            if let s = item.stringValue, !s.isEmpty { album = s }
                        default:
                            break
                        }
                    }
                    pending[f.path] = CachedMeta(mtime: f.mtime, title: title, artist: artist, album: album)
                }
                processed += 1
                if processed % 150 == 0 {
                    let batch = pending
                    pending.removeAll()
                    DispatchQueue.main.async { self.applyMeta(batch, save: true) }
                }
            }
            let last = pending
            DispatchQueue.main.async { self.applyMeta(last, save: true) }
        }
    }

    private func applyMeta(_ meta: [String: CachedMeta], save: Bool) {
        if !meta.isEmpty {
            for (path, m) in meta { metaCache[path] = m }
            tracks = tracks.map { t in
                guard let m = meta[t.relativePath] else { return t }
                var nt = t
                nt.title = m.title
                nt.artist = m.artist
                nt.album = m.album
                return nt
            }
            tracks.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            rebuildGroups()
        }
        if save { saveCache() }
    }

    private func loadCache() {
        guard let data = FileManager.default.contents(atPath: Library.cachePath),
              let decoded = try? JSONDecoder().decode([String: CachedMeta].self, from: data) else { return }
        metaCache = decoded
    }

    private func saveCache() {
        if let data = try? JSONEncoder().encode(metaCache) {
            try? data.write(to: URL(fileURLWithPath: Library.cachePath))
        }
    }

    private func rebuildGroups() {
        var albumSet = Set<String>()
        var artistSet = Set<String>()
        var albumArt: [String: String] = [:]
        var artistArt: [String: String] = [:]
        for t in tracks {
            albumSet.insert(t.album)
            if albumArt[t.album] == nil { albumArt[t.album] = t.relativePath }
            if !t.artist.isEmpty {
                artistSet.insert(t.artist)
                if artistArt[t.artist] == nil { artistArt[t.artist] = t.relativePath }
            }
        }
        albums = albumSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        artists = artistSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        albumArtKey = albumArt
        artistArtKey = artistArt
    }

    static func cleanName(_ url: URL) -> String {
        var name = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ")
        if let range = name.range(of: "^\\s*\\d{1,3}\\s*[-.)]?\\s*", options: .regularExpression) {
            name.removeSubrange(range)
        }
        name = name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? url.lastPathComponent : name
    }
}
