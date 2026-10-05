import Foundation

enum YouTubeThumbnail {
    static func url(for page: URL) -> URL? {
        videoID(in: page).flatMap { URL(string: "https://i.ytimg.com/vi/\($0)/mqdefault.jpg") }
    }

    private static func videoID(in url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let path = url.pathComponents.dropFirst()
        if host.hasSuffix("youtu.be") {
            return path.first
        }
        guard host.hasSuffix("youtube.com") else { return nil }
        if path.first == "watch" {
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "v" }?.value
        }
        if ["shorts", "embed", "live"].contains(path.first ?? ""), path.count > 1 {
            return path[path.index(path.startIndex, offsetBy: 1)]
        }
        return nil
    }
}
