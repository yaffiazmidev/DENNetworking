//
//  DENHTTPClient.swift
//
//
//  Created by DENAZMI on 03/09/24.
//

import Foundation

public protocol DENHTTPClient {
    /// The completion handler can be invoked in any thread.
    /// Clients are responsible to dispatch to appropriate threads, if needed.
    @discardableResult
    func request(from request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
