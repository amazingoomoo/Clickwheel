import Foundation

struct Track: Identifiable, Equatable {
    let url: URL
    let relativePath: String   // stable identity relative to Documents
    var title: String
    var artist: String
    var album: String

    var id: String { relativePath }

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.relativePath == rhs.relativePath }
}

struct Playlist: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var trackPaths: [String]
}
