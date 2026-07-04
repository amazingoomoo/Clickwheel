import Foundation
import Combine
import AVFoundation

final class Library: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var albums: [String] = []
    @Published var artists: [String] = []

    private let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "alac", "wav", "aif", "aiff", "caf", "m4b", "flac"]

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init() { scan() }

    func track(withPath path: String) -> Track? { tracks.first { $0.relativePath == path } }
    func tracksInAlbum(_ album: String) -> [Track] { tracks.filter { $0.album == album } }
    func tracksByArtist(_ artist: String) -> [Track] {
        tracks.filter { $0.artist == artist }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func scan() {
        let docs = Library.documentsURL
        let base = docs.path
        var found: [Track] = []
        if let enumerator = FileManager.default.enumerator(at: docs, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where audioExtensions.contains(url.pathExtension.lowercased()) {
                var rel = url.path
                if rel.hasPrefix(base) {
                    rel = String(rel.dropFirst(base.count))
                    if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
                }
                found.append(Track(url: url, relativePath: rel, title: Library.cleanName(url), artist: "", album: "Unknown Album"))
            }
        }
        found.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        DispatchQueue.main.async {
            self.tracks = found
            self.rebuildGroups()
        }
        loadMetadata(for: found)
    }

    private func loadMetadata(for list: [Track]) {
        DispatchQueue.global(qos: .userInitiated).async {
            var updated = list
            for i in updated.indices {
                let asset = AVURLAsset(url: updated[i].url)
                for item in asset.commonMetadata {
                    guard let key = item.commonKey else { continue }
                    switch key {
                    case .commonKeyTitle:
                        if let s = item.stringValue, !s.isEmpty { updated[i].title = s }
                    case .commonKeyArtist:
                        if let s = item.stringValue, !s.isEmpty { updated[i].artist = s }
                    case .commonKeyAlbumName:
                        if let s = item.stringValue, !s.isEmpty { updated[i].album = s }
                    default:
                        break
                    }
                }
            }
            updated.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            DispatchQueue.main.async {
                self.tracks = updated
                self.rebuildGroups()
            }
        }
    }

    private func rebuildGroups() {
        var albumSet = Set<String>()
        var artistSet = Set<String>()
        for t in tracks {
            albumSet.insert(t.album)
            if !t.artist.isEmpty { artistSet.insert(t.artist) }
        }
        albums = albumSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        artists = artistSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
