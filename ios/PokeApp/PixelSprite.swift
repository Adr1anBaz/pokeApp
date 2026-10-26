import ImageIO
import SwiftUI
import UIKit

/// Decoded frames of an animated GIF (or a single PNG frame) and their durations.
final class SpriteFrames: @unchecked Sendable {  // immutable after decoding
    let frames: [UIImage]
    let durations: [Double]
    let total: Double
    /// Size of the image in pixels (not points), used to keep every Pokémon's real proportions.
    let pixelSize: CGSize

    init(frames: [UIImage], durations: [Double], pixelSize: CGSize) {
        self.frames = frames
        self.durations = durations
        self.total = max(durations.reduce(0, +), 0.01)
        self.pixelSize = pixelSize
    }

    func frame(at date: Date) -> UIImage {
        guard frames.count > 1 else { return frames[0] }
        var t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: total)
        for (index, duration) in durations.enumerated() {
            if t < duration { return frames[index] }
            t -= duration
        }
        return frames[frames.count - 1]
    }
}

/// Downloads and decodes sprites once (SwiftUI's AsyncImage does not animate GIFs).
actor SpriteLoader {
    static let shared = SpriteLoader()
    private var cache: [String: SpriteFrames] = [:]
    private var missing: Set<String> = []

    func load(_ url: String) async -> SpriteFrames? {
        if let cached = cache[url] { return cached }
        if missing.contains(url) { return nil }
        guard let remote = URL(string: url),
              let (data, response) = try? await URLSession.shared.data(from: remote),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = Self.decode(data) else {
            missing.insert(url)
            return nil
        }
        cache[url] = decoded
        return decoded
    }

    private static func decode(_ data: Data) -> SpriteFrames? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        var frames: [UIImage] = []
        var durations: [Double] = []
        var pixelSize = CGSize.zero
        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            if frames.isEmpty { pixelSize = CGSize(width: cgImage.width, height: cgImage.height) }
            frames.append(UIImage(cgImage: cgImage))
            durations.append(frameDuration(source, index))
        }
        guard !frames.isEmpty else { return nil }
        return SpriteFrames(frames: frames, durations: durations, pixelSize: pixelSize)
    }

    private static func frameDuration(_ source: CGImageSource, _ index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
        let delay = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gif[kCGImagePropertyGIFDelayTime] as? Double)
            ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }
}

/// Pixel-art sprite drawn at [scale] points per image pixel, so every Pokémon keeps its real
/// proportions. Falls back to [fallbackURL] (static sprite) when the animated one is missing.
/// [tint] fills the sprite's silhouette (white flash on send-out, red when recalled).
struct PixelSprite: View {
    let url: String
    let fallbackURL: String?
    let scale: CGFloat
    var tint: Color = .clear
    var tintAmount: Double = 0

    @State private var sprite: SpriteFrames?

    var body: some View {
        Group {
            if let sprite {
                let size = CGSize(width: sprite.pixelSize.width * scale, height: sprite.pixelSize.height * scale)
                TimelineView(.animation(minimumInterval: nil, paused: sprite.frames.count < 2)) { context in
                    let frame = sprite.frame(at: context.date)
                    Image(uiImage: frame)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                        .overlay(
                            tint
                                .opacity(tintAmount)
                                .mask(Image(uiImage: frame).interpolation(.none).resizable())
                        )
                }
                .frame(width: size.width, height: size.height)
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .task(id: url) {
            var loaded = await SpriteLoader.shared.load(url)
            if loaded == nil, let fallbackURL { loaded = await SpriteLoader.shared.load(fallbackURL) }
            sprite = loaded
        }
    }
}
