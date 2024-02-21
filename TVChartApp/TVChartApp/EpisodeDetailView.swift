import SwiftUI

struct EpisodeDetailView: View {
  @Binding var episode: SeasonItem?
  @State private var metadata: DataState<EpisodeMetadata> = .loading

  private var positionDescription: String {
    guard let episode else { return ""}

    switch episode.kind {
      case let .episode(number, _): return "episode \(number)"
      case .special: return "special"
      default: return "—"
    }
  }

  func fetchMetadata(episode: SeasonItem) async throws -> EpisodeMetadata {
    return try await MetadataService().getEpisodeMetadata(
      forShow: episode.season.show,
      season: episode.season.number,
      episodeIndex: episode.index
    )
  }

  var body: some View {
    return VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {

        switch metadata {
          case let .ready(metadata):
            Text(metadata.title).font(.title3).fontWeight(.heavy)
          case .loading:
            ProgressView()
          default:
            EmptyView()
        }

        Spacer()
        Toggle("Watched", isOn: .constant(true)).labelsHidden()
      }
      Text(episode?.season.show.title ?? "").font(.footnote).italic().bold()
      Text("Season \(episode?.season.number ?? 0), \(positionDescription)")
        .font(.footnote)

      SynopsisView(metadata)

      Button {
        // TBD
      } label: {
        Text("Mark all episodes watched up to here")
      }.buttonStyle(.borderedProminent)
        .padding([.top], 15)
    }.padding()
      .task {
        if let episode {
          do {
            metadata = .ready(try await fetchMetadata(episode: episode))
          } catch {
            handleError(error)
          }
        }
      }
  }
}

struct SynopsisView: View {
  let metadata: DataState<EpisodeMetadata>

  init(_ metadata: DataState<EpisodeMetadata>) {
    self.metadata = metadata
  }

  var body: some View {
    switch metadata {

      case let .ready(metadata):
        var summaryView: Text
        if let synopsis = metadata.synopsis {
          summaryView = Text(synopsis)
        } else {
          summaryView = Text("No summary available").italic()
        }
        return AnyView(
          summaryView
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.footnote)
            .padding(10)
            .padding([.leading, .trailing], 5)
            .background(Color(white: 0.97))
            .border(Color(white: 0.75))
            .padding([.top], 10)
        )

      case .loading:
        return AnyView(ProgressView())

      default:
        return AnyView(EmptyView())
    }
  }
}

#Preview {
  let item = SeasonItem(index: 0, kind: .episode(number: 1, status: .unwatched))
  let season = Season(number: 1, items: [item])
  let show = Show(title: "test", tvmazeId: "1", favorite: .unfavorited, location: "Netflix", episodeLength: "60 min.", seasons: [season])
  item.season = season
  season.show = show
  return EpisodeDetailView(episode: .constant(item))
    .previewLayout(.fixed(width: 50, height: 50))
    .previewDisplayName("Sheet")
}
