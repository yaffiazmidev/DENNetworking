//
//  File.swift
//  
//
//  Created by DENAZMI on 03/09/24.
//

import Foundation

internal final class DENMapper<T: Codable> {
    static func map(_ data: Data, from response: HTTPURLResponse) throws -> T {
        guard (200...299).contains(response.statusCode) else { if let error = try? JSONDecoder().decode(DENNetworkErrorResponse.self, from: data) {
            throw DENNetworkError.response(error)
        }
            throw DENNetworkError.connectivity
        }
        
        guard let response = try? JSONDecoder().decode(T.self, from: data) else {
            throw DENNetworkError.invalidData
        }
        
        return response
    }
}
