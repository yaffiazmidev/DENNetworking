import Foundation
@testable import DENNetworking

final class HTTPClientStub: DENNetworkHTTPClient, @unchecked Sendable {
    private let result: Result<(Data, HTTPURLResponse), Error>

    init(result: Result<(Data, HTTPURLResponse), Error>) {
        self.result = result
    }

    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        return try result.get()
    }

    // MARK: - Factory

    static func success(data: Data = Data(), statusCode: Int = 200, url: URL = URL(string: "https://test.com")!) -> HTTPClientStub {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return HTTPClientStub(result: .success((data, response)))
    }

    static func failure(_ error: Error) -> HTTPClientStub {
        return HTTPClientStub(result: .failure(error))
    }
}
