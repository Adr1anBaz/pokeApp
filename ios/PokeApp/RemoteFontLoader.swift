import CoreText
import CryptoKit
import Foundation
import SwiftUI
import UIKit

@MainActor
final class RemoteFontLoader: ObservableObject {
    @Published private(set) var isReady = false

    private struct RemoteFont {
        let fileName: String
        let postScriptName: String
        let url: URL
        let sha256: String
    }

    private static let maximumFontSize = 1_000_000
    private static let allowedHosts: Set<String> = ["raw.githubusercontent.com"]
    private static let allowedContentTypes: Set<String> = [
        "application/octet-stream",
        "application/font-sfnt",
        "application/x-font-ttf",
        "font/sfnt",
        "font/ttf"
    ]

    private let fonts = [
        RemoteFont(
            fileName: "PressStart2P-Regular.ttf",
            postScriptName: "PressStart2P-Regular",
            url: URL(string: "https://raw.githubusercontent.com/google/fonts/61e281d0f2d8a299369944ede7483454695985aa/ofl/pressstart2p/PressStart2P-Regular.ttf")!,
            sha256: "034c77f1f05ec89421e4a63f0e3a4ca1ecf852cc6d2bf611f126f275728e017d"
        ),
        RemoteFont(
            fileName: "PixelifySans.ttf",
            postScriptName: "PixelifySans-Regular",
            url: URL(string: "https://raw.githubusercontent.com/google/fonts/61e281d0f2d8a299369944ede7483454695985aa/ofl/pixelifysans/PixelifySans%5Bwght%5D.ttf")!,
            sha256: "9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5"
        )
    ]

    func prepare() async {
        for font in fonts {
            await registerOrDownload(font)
        }
        isReady = fonts.allSatisfy { UIFont(name: $0.postScriptName, size: 12) != nil }
    }

    private func registerOrDownload(_ font: RemoteFont) async {
        guard let directory = try? fontDirectory() else { return }
        let destination = directory.appendingPathComponent(font.fileName, isDirectory: false)

        if isValidCachedFont(at: destination, matching: font.sha256),
           registerFont(at: destination, named: font.postScriptName) { return }

        try? FileManager.default.removeItem(at: destination)

        do {
            guard isAllowedRemoteFontURL(font.url) else { return }

            var request = URLRequest(url: font.url)
            request.timeoutInterval = 10
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse,
                  let finalURL = http.url,
                  isAllowedRemoteFontURL(finalURL),
                  (200...299).contains(http.statusCode),
                  http.expectedContentLength > 0,
                  http.expectedContentLength <= Self.maximumFontSize,
                  let contentType = http.mimeType?.lowercased(),
                  Self.allowedContentTypes.contains(contentType) else { return }

            var data = Data()
            data.reserveCapacity(Int(http.expectedContentLength))
            for try await byte in bytes {
                guard data.count < Self.maximumFontSize else { return }
                data.append(byte)
            }
            guard isValidFontData(data, matching: font.sha256) else { return }

            try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            guard registerFont(at: destination, named: font.postScriptName) else {
                try? FileManager.default.removeItem(at: destination)
                return
            }
        } catch {
            // The app keeps using the monospaced system fallback if a remote font is unavailable.
        }
    }

    private func fontDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("PokeApp/Fonts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func isAllowedRemoteFontURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.host.map { Self.allowedHosts.contains($0.lowercased()) } == true
    }

    private func isValidCachedFont(at url: URL, matching sha256: String) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return isValidFontData(data, matching: sha256)
    }

    private func isValidFontData(_ data: Data, matching sha256: String) -> Bool {
        guard !data.isEmpty, data.count <= Self.maximumFontSize else { return false }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return digest == sha256
    }

    private func registerFont(at url: URL, named postScriptName: String) -> Bool {
        if UIFont(name: postScriptName, size: 12) != nil { return true }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        return UIFont(name: postScriptName, size: 12) != nil
    }
}
