import Foundation

struct NowPlayingItemViewModel: Identifiable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let voteAverage: Double
    let releaseDate: String
}

extension Array where Element == RemoteNowPlayingItem {
    var asViewModels: [NowPlayingItemViewModel] {
        map({ .init(id: $0.id ?? 0, title: $0.title ?? "", overview: $0.overview ?? "", voteAverage: $0.voteAverage ?? 0, releaseDate: $0.releaseDate ?? "") })
    }
}
