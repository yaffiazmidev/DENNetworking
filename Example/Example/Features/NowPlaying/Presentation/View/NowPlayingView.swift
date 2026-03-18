import SwiftUI

struct NowPlayingView: View {
    @Environment(AppRouter.self) var router
    @State var viewModel: NowPlayingViewModel

    var body: some View {
        VStack {
            Text("Now Playing Movies")
            ScrollView(showsIndicators: false) {
                if viewModel.isLoading {
                    loadingView()
                } else if let message = viewModel.errorMessage {
                    errorView(with: message)
                } else if viewModel.items.isEmpty {
                    emptyView()
                } else {
                    ForEach(viewModel.items) { item in
                        movieRow(item)
                            .onTapGesture {
                                router.push(.movieDetail(movieId: item.id))
                            }
                    }
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
        .padding()
        .task {
            await viewModel.loadData()
        }
    }

    private func movieRow(_ item: NowPlayingItemViewModel) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Text(item.overview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(String(format: "%.1f", item.voteAverage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.releaseDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray.opacity(0.8))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func loadingView() -> some View {
        ProgressView("Loading...")
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowSeparator(.hidden)
    }

    private func emptyView() -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.gray)
            Text("No items yet")
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
    let dependencies = AppDependencies()
    let viewModel = dependencies.makeNowPlayingViewModel()
    NowPlayingView(viewModel: viewModel)
        .environment(AppRouter())
}
