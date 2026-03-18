import Foundation
import DENNetworking

final class MockHTTPClient: DENNetworkHTTPClient, @unchecked Sendable {

    private let result: Result<(Data, HTTPURLResponse), Error>
    private(set) var loadedRequests: [URLRequest] = []

    init(result: Result<(Data, HTTPURLResponse), Error>) {
        self.result = result
    }

    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        loadedRequests.append(request)
        return try result.get()
    }

    // MARK: - Factory

    static func success(
        data: Data = Data(),
        statusCode: Int = 200,
        url: URL = URL(string: "https://api.themoviedb.org")!
    ) -> MockHTTPClient {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return MockHTTPClient(result: .success((data, response)))
    }

    static func failure(_ error: Error) -> MockHTTPClient {
        return MockHTTPClient(result: .failure(error))
    }
}
