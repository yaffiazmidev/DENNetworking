import SwiftUI

/// Interactive star rating (5 stars, supports half-star via tap position).
///
/// Maps 5 stars to TMDB's 0.5–10.0 scale (each star = 2.0 points).
struct StarRatingView: View {

    @Binding var rating: Double

    private let starCount = 5
    private let starSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...starCount, id: \.self) { index in
                starImage(for: index)
                    .font(.system(size: starSize))
                    .foregroundStyle(.yellow)
                    .onTapGesture {
                        rating = Double(index) * 2.0
                    }
            }
        }
    }

    private func starImage(for index: Int) -> Image {
        let starValue = Double(index) * 2.0
        if rating >= starValue {
            return Image(systemName: "star.fill")
        } else if rating >= starValue - 1.0 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }
}
