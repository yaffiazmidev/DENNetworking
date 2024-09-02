//
//  File.swift
//  
//
//  Created by DENAZMI on 03/09/24.
//

import Foundation

public struct DENNetworkErrorResponse: Codable {
    public let success: Bool?
    public let message: String?
}

public enum DENNetworkError: Error {
    case connectivity
    case invalidData
    case response(DENNetworkErrorResponse)
}

extension DENNetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connectivity: return "Tidak ada koneksi internet"
        case .invalidData: return "Gagal memuat data"
        case .response(let response): return response.message ?? "Terjadi Kesalahan"
        }
    }
}
