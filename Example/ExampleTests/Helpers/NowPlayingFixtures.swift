import Foundation

enum NowPlayingFixtures {

    static func itemsJSON(page: Int = 1, totalPages: Int = 10) -> Data {
        let json = """
        {
            "page": \(page),
            "total_pages": \(totalPages),
            "total_results": 200,
            "results": [
                {
                    "id": 1,
                    "title": "Test Movie 1",
                    "overview": "A great movie",
                    "poster_path": "/test.jpg",
                    "vote_average": 7.5,
                    "release_date": "2025-01-01"
                },
                {
                    "id": 2,
                    "title": "Test Movie 2",
                    "overview": "Another great movie",
                    "poster_path": null,
                    "vote_average": 8.0,
                    "release_date": "2025-02-01"
                }
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
}
