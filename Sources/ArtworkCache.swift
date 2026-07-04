import SwiftUI
import AVFoundation
import UIKit

final class ArtworkCache {
    static let shared = ArtworkCache()

    private var cache: [String: UIImage] = [:]
    private var waiters: [String: [(UIImage?) -> Void]] = [:]
    private let queue = DispatchQueue(label: "cw.artwork", qos: .utility)

    // Called on the main thread from views.
    func thumbnail(for path: String, completion: @escaping (UIImage?) -> Void) {
        if let img = cache[path] { completion(img); return }
        if waiters[path] != nil { waiters[path]?.append(completion); return }
        waiters[path] = [completion]
        let url = URL(fileURLWithPath: path)
        queue.async { [weak self] in
            let img = ArtworkCache.load(url)
            DispatchQueue.main.async {
                if let img = img { self?.cache[path] = img }
                let callbacks = self?.waiters[path] ?? []
                self?.waiters[path] = nil
                callbacks.forEach { $0(img) }
            }
        }
    }

    private static func load(_ url: URL, maxDim: CGFloat = 44) -> UIImage? {
        let asset = AVURLAsset(url: url)
        for item in asset.commonMetadata where item.commonKey == .commonKeyArtwork {
            if let data = item.dataValue, let full = UIImage(data: data) {
                return downscale(full, maxDim: maxDim)
            }
        }
        return nil
    }

    private static func downscale(_ image: UIImage, maxDim: CGFloat) -> UIImage {
        let size = image.size
        let factor = min(maxDim / max(size.width, 1), maxDim / max(size.height, 1), 1)
        let newSize = CGSize(width: max(1, size.width * factor), height: max(1, size.height * factor))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

struct ThumbnailView: View {
    @Environment(\.appTheme) var theme
    let path: String
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                theme.divider.overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundColor(theme.muted)
                )
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .onAppear { load() }
        .onChange(of: path) { _ in
            image = nil
            load()
        }
    }

    private func load() {
        let p = path
        ArtworkCache.shared.thumbnail(for: p) { img in
            if p == path, let img = img { image = img }
        }
    }
}
