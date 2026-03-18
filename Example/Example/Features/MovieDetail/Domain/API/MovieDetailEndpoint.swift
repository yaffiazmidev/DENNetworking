import Foundation
import DENNetworking

enum MovieDetailEndpoint {
    case getDetail(movieId: Int)

    func makeRequest() throws -> URLRequest {
        switch self {
        case .getDetail(let movieId):
            return try URLRequest
                .path("movie/\(movieId)")
                .build()
        }
    }
}
