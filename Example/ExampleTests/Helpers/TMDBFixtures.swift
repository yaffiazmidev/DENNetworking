import Foundation

enum TMDBFixtures {

    static func popularMoviesJSON(page: Int = 1, totalPages: Int = 10) -> Data {
        let json = """
        {
            "page": \(page),
            "total_pages": \(totalPages),
            "total_results": 200,
            "results": [
                {
                    "id": 1,
                    "title": "Test Movie",
                    "overview": "A great movie",
                    "poster_path": "/test.jpg",
                    "backdrop_path": "/backdrop.jpg",
                    "vote_average": 8.5,
                    "vote_count": 1000,
                    "release_date": "2025-01-01",
                    "popularity": 100.0
                },
                {
                    "id": 2,
                    "title": "Another Movie",
                    "overview": "Another great movie",
                    "poster_path": null,
                    "backdrop_path": null,
                    "vote_average": 7.2,
                    "vote_count": 500,
                    "release_date": "2025-06-15",
                    "popularity": 80.0
                }
            ]
        }
        """
        return Data(json.utf8)
    }

    static func movieDetailJSON(id: Int = 1) -> Data {
        let json = """
        {
            "id": \(id),
            "title": "Test Movie",
            "overview": "A great movie about testing",
            "poster_path": "/test.jpg",
            "backdrop_path": "/backdrop.jpg",
            "vote_average": 8.5,
            "vote_count": 1000,
            "release_date": "2025-01-01",
            "runtime": 120,
            "status": "Released",
            "tagline": "Testing is fun",
            "genres": [
                {"id": 28, "name": "Action"},
                {"id": 12, "name": "Adventure"}
            ]
        }
        """
        return Data(json.utf8)
    }

    static let emptyResultsJSON = Data("""
    {
        "page": 1,
        "total_pages": 0,
        "total_results": 0,
        "results": []
    }
    """.utf8)

    // MARK: - CRUD Responses

    static func statusResponseJSON(statusCode: Int = 1, message: String = "Success.") -> Data {
        let json = """
        {
            "status_code": \(statusCode),
            "status_message": "\(message)"
        }
        """
        return Data(json.utf8)
    }
}
