import Foundation

struct MovieDetailItemViewModel: Identifiable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let tagline: String
    let voteAverage: Double
    let voteCount: Int
    let releaseDate: String
    let runtime: String?
    let genres: String

    var ratingText: String {
        String(format: "%.1f", voteAverage)
    }
}

extension RemoteMovieDetail {
    var asViewModel: MovieDetailItemViewModel {
        MovieDetailItemViewModel(
            id: id ?? 0,
            title: title ?? "",
            overview: overview ?? "",
            tagline: tagline ?? "",
            voteAverage: voteAverage ?? 0,
            voteCount: voteCount ?? 0,
            releaseDate: releaseDate ?? "",
            runtime: runtimeText,
            genres: genres?.compactMap(\.name).joined(separator: ", ") ?? ""
        )
    }

    private var runtimeText: String? {
        guard let runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
