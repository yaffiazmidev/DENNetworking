import Foundation
import DENNetworking

protocol NowPlayingServiceProtocol {
    func getItems() async throws -> [RemoteNowPlayingItem]
}

final class NowPlayingService: NowPlayingServiceProtocol {

    private let networkService: DENNetworkingServiceProtocol

    init(networkService: DENNetworkingServiceProtocol) {
        self.networkService = networkService
    }

    func getItems() async throws -> [RemoteNowPlayingItem] {
        let request = try NowPlayingEndpoint.getItems().makeRequest()
        let response: TMDBResponse = try await networkService.execute(request)
        return response.results ?? []
    }
}
