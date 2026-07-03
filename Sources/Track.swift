import Foundation

struct Track: Identifiable, Equatable {
    let url: URL
    var id: URL { url }

    /// A tidied-up name derived from the filename: strips the extension,
    /// converts underscores to spaces, and removes leading track numbers
    /// like "01 ", "01 - " or "01. ".
    var displayTitle: String {
        var name = url.deletingPathExtension().lastPathComponent
        name = name.replacingOccurrences(of: "_", with: " ")
        if let range = name.range(
            of: "^\\s*\\d{1,3}\\s*[-.)]?\\s*",
            options: .regularExpression
        ) {
            name.removeSubrange(range)
        }
        name = name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? url.lastPathComponent : name
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.url == rhs.url
    }
}
