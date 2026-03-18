import Foundation

public protocol DENNetworkConfigurable {
    var baseURL: URL { get }
    var headers: [String: String] { get }
    var queryParameters: [String: String] { get }
}

public struct DENApiNetworkConfig: DENNetworkConfigurable {
    public let baseURL: URL
    public let headers: [String: String]
    public let queryParameters: [String: String]
    
     public init(
        baseURL: URL,
        headers: [String: String] = [:],
        queryParameters: [String: String] = [:]
     ) {
        self.baseURL = baseURL
        self.headers = headers
        self.queryParameters = queryParameters
    }
}
