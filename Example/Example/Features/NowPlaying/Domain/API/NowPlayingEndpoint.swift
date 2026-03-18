import Foundation
import DENNetworking

enum NowPlayingEndpoint {
    case getItems(page: Int = 1)

    func makeRequest() throws -> URLRequest {
        switch self {
        case .getItems(let page):
            return try URLRequest
                .path("movie/now_playing")
                .queries([.init(name: "page", value: "\(page)")])
                .build()
        }
    }
}
