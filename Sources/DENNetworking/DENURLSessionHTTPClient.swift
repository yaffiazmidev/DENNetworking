//
//  DENURLSessionHTTPClient.swift
//
//
//  Created by DENAZMI on 03/09/24.
//

import Foundation

public final class DENURLSessionHTTPClient: DENHTTPClient {
    
    private let session: URLSession
    
    public init(session: URLSession) {
        self.session = session
    }
    
    private struct UnexpectedValuesRepresentation : Error {}
    
    public func request(from request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        
        if Task.isCancelled {
            try Task.checkCancellation()
        }
        
        let task = Task {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw UnexpectedValuesRepresentation()
                }
                
                return (data, httpResponse)
                
            } catch {
                throw error
            }
        }
        
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
