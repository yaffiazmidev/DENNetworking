import SwiftUI

struct MovieDetailView: View {
    @Environment(AppRouter.self) var router
    @State var viewModel: MovieDetailViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            if viewModel.isLoading {
                loadingView()
            } else if let message = viewModel.errorMessage {
                errorView(with: message)
            } else if let detail = viewModel.detail {
                detailContent(detail)
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    private func detailContent(_ detail: MovieDetailItemViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.title)
                    .font(.title)
                    .fontWeight(.bold)

                if !detail.tagline.isEmpty {
                    Text(detail.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            HStack(spacing: 12) {
                Label(detail.ratingText, systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline)

                Text("(\(detail.voteCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let runtime = detail.runtime {
                    Label(runtime, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(detail.releaseDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !detail.genres.isEmpty {
                Text(detail.genres)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text("Overview")
                .font(.headline)

            Text(detail.overview)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func loadingView() -> some View {
        ProgressView("Loading...")
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 32)
    }

    private func errorView(with message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.red)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview {
    NavigationStack {
        let dependencies = AppDependencies()
        let viewModel = dependencies.makeMovieDetailViewModel(movieId: 550)
        MovieDetailView(viewModel: viewModel)
            .environment(AppRouter())
    }
}
