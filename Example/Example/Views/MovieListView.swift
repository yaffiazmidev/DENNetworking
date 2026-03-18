import SwiftUI

struct MovieListView: View {

    @State private var viewModel = MovieListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.movies.isEmpty {
                    ProgressView("Loading movies...")
                } else if let error = viewModel.errorMessage, viewModel.movies.isEmpty {
                    errorView(error)
                } else {
                    movieList
                }
            }
            .navigationTitle("Popular Movies")
            .searchable(text: $viewModel.searchText, prompt: "Search movies...")
            .onChange(of: viewModel.searchText) {
                Task { await viewModel.search() }
            }
            .task {
                await viewModel.loadPopularMovies()
            }
        }
    }

    private var movieList: some View {
        List {
            ForEach(viewModel.displayedMovies) { movie in
                NavigationLink(value: movie.id) {
                    MovieRow(movie: movie)
                }
            }

            if viewModel.searchText.isEmpty && viewModel.hasMorePages {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .task { await viewModel.loadNextPage() }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Int.self) { movieId in
            MovieDetailView(movieId: movieId)
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await viewModel.loadPopularMovies() }
            }
        }
    }
}

// MARK: - Movie Row

struct MovieRow: View {

    let movie: Movie

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: movie.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay { Image(systemName: "film").foregroundStyle(.gray) }
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                if let date = movie.releaseDate, !date.isEmpty {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(movie.ratingText)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
