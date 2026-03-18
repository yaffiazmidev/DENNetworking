import Foundation

enum MovieDetailFixtures {

    static func detailJSON(id: Int = 550) -> Data {
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
            "runtime": 142,
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

    static func detailWithoutRuntimeJSON() -> Data {
        let json = """
        {
            "id": 1,
            "title": "No Runtime Movie",
            "overview": "Overview",
            "poster_path": null,
            "backdrop_path": null,
            "vote_average": 6.0,
            "vote_count": 50,
            "release_date": "2025-06-15",
            "runtime": null,
            "status": "Released",
            "tagline": "",
            "genres": []
        }
        """
        return Data(json.utf8)
    }
}
