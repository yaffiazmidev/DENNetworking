//
//  File.swift
//  
//
//  Created by DENAZMI on 03/09/24.
//

import Foundation

internal class DENGenericLoader<T: Codable> {
    
    private init() {}
    
    typealias Result = Swift.Result<T, Error>
    
    class func load(request: URLRequest, completion: @escaping (Result) -> Void) {
        let client = DENHTTPClientFactory.makeURLSessionHttpClient()
        
        Task {
            do {
                let (data, response) = try await client.request(from: request)
                completion(map(data, from: response))
            } catch {
                completion(.failure(DENNetworkError.connectivity))
            }
        }
    }
    
    private class func map(_ data: Data, from response: HTTPURLResponse) -> Result {
        do {
            let item = try DENMapper<T>.map(data, from: response)
            return .success(item)
        } catch {
            return .failure(error)
        }
    }
}
