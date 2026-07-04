import SwiftUI
import AVFoundation
import UIKit
import ImageIO

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
        return autoreleasepool { () -> UIImage? in
            let asset = AVURLAsset(url: url)
            for item in asset.commonMetadata where item.commonKey == .commonKeyArtwork {
                if let data = item.dataValue {
                    return thumbnail(from: data, maxPixel: maxDim * UIScreen.main.scale)
                }
            }
            return nil
        }
    }

    private static func thumbnail(from data: Data, maxPixel: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel)
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
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
