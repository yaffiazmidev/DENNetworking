import SwiftUI

struct MovieDetailView: View {

    let movieId: Int
    @State private var viewModel: MovieDetailViewModel

    init(movieId: Int) {
        self.movieId = movieId
        self._viewModel = State(wrappedValue: MovieDetailViewModel(movieId: movieId))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if let detail = viewModel.detail {
                detailContent(detail)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadDetail() }
                    }
                }
            }
        }
        .navigationTitle(viewModel.detail?.title ?? "Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDetail()
        }
    }

    private func detailContent(_ detail: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            posterSection(detail)
            infoSection(detail)
            crudActionsSection
            overviewSection(detail)
        }
        .padding(.bottom, 32)
    }

    // MARK: - Poster

    private func posterSection(_ detail: MovieDetail) -> some View {
        AsyncImage(url: detail.posterURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(2/3, contentMode: .fit)
                .overlay { Image(systemName: "film").font(.largeTitle).foregroundStyle(.gray) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Info

    private func infoSection(_ detail: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(detail.title)
                .font(.title)
                .fontWeight(.bold)

            if let tagline = detail.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label(detail.runtimeText ?? "N/A", systemImage: "clock")
                Label {
                    Text(String(format: "%.1f", detail.voteAverage))
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
                Label(detail.releaseDate ?? "N/A", systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !detail.genres.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(detail.genres) { genre in
                        Text(genre.name)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - CRUD Actions

    private var crudActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("Actions")
                .font(.headline)

            // Feedback messages
            if let success = viewModel.successMessage {
                Label(success, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            // Star rating
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Rating: \(String(format: "%.1f", viewModel.userRating))")
                    .font(.subheadline)
                StarRatingView(rating: $viewModel.userRating)
            }

            // Create (POST) — Rate Movie
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.rateMovie() }
                } label: {
                    Label("Rate", systemImage: "star")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)

                // Update (PUT) — Update Rating
                Button {
                    Task { await viewModel.updateRating() }
                } label: {
                    Label("Update", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                // Delete (DELETE) — Delete Rating
                Button(role: .destructive) {
                    Task { await viewModel.deleteRating() }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            // Create/Update (POST/PUT) — Watchlist
            Button {
                Task {
                    if viewModel.isInWatchlist {
                        await viewModel.removeFromWatchlist()
                    } else {
                        await viewModel.addToWatchlist()
                    }
                }
            } label: {
                Label(
                    viewModel.isInWatchlist ? "Remove from Watchlist" : "Add to Watchlist",
                    systemImage: viewModel.isInWatchlist ? "bookmark.fill" : "bookmark"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isInWatchlist ? .red : .green)

            if viewModel.isActioning {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            Divider()
        }
        .padding(.horizontal)
        .disabled(viewModel.isActioning)
    }

    // MARK: - Overview

    private func overviewSection(_ detail: MovieDetail) -> some View {
        Group {
            if !detail.overview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.headline)

                    Text(detail.overview)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Simple FlowLayout

struct FlowLayout: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
