//
//  DENHTTPClientFactory.swift
//  
//
//  Created by DENAZMI on 03/09/24.
//

import Foundation

public final class DENHTTPClientFactory {
    
    private init() {}
    
    private static func makeTimeOutURLSession(headers: [AnyHashable: Any]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0
        configuration.timeoutIntervalForResource = 10.0
        configuration.httpAdditionalHeaders = headers

        return URLSession(configuration: configuration)
    }
    
    public static func makeURLSessionHttpClient(headers: [AnyHashable: Any]? = nil) -> DENHTTPClient {
        return DENURLSessionHTTPClient(session: makeTimeOutURLSession(headers: headers))
    }
}
