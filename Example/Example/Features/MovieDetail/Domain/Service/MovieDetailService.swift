import Foundation
import DENNetworking

protocol MovieDetailServiceProtocol {
    func getDetail(movieId: Int) async throws -> RemoteMovieDetail
}

final class MovieDetailService: MovieDetailServiceProtocol {

    private let networkService: DENNetworkingServiceProtocol

    init(networkService: DENNetworkingServiceProtocol) {
        self.networkService = networkService
    }

    func getDetail(movieId: Int) async throws -> RemoteMovieDetail {
        let request = try MovieDetailEndpoint.getDetail(movieId: movieId).makeRequest()
        return try await networkService.execute(request)
    }
}
