import Foundation
import SwiftUI

struct EpisodeDetailView: View {
  @Environment(ContentView.DisplayState.self) var displayState
  @Binding var episode: Episode
  @State private var metadata: DataState<EpisodeMetadata> = .loading

  private var episodeDescription: String {
    let desc: String, length: String

    switch episode {
      case let numberedEpisode as NumberedEpisode:
        desc = "episode \(numberedEpisode.episodeNumber)"
      case is SpecialEpisode:
        desc = "special"
      default:
        desc = "?"
    }

    switch metadata {
      case let .ready(metadata): length = " — \(metadata.length)"
      default: length = ""
    }

    return desc + length
  }

  func fetchMetadata(episode: Episode) async throws -> EpisodeMetadata {
    return try await MetadataService().getEpisodeMetadata(
      forShow: episode.season.show,
      season: episode.season.number,
      episodeIndex: episode.episodeIndex
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
        Toggle("Watched", isOn: $episode.isWatched).labelsHidden()
      }
      Text(episode.season.show.title)
      Text("Season \(episode.season.number), \(episodeDescription)")
        .font(.footnote)

      SynopsisView(metadata)

      Button {
        handleMarkWatchedToEpisode(episode: episode, backend: displayState.backend)
      } label: {
        Text("Mark all episodes watched up to here")
        .frame(maxWidth: .infinity)
      }.buttonStyle(.borderedProminent)
        .padding([.top], 15)
    }.padding()
      .task {
        do {
          metadata = .ready(try await fetchMetadata(episode: episode))
        } catch {
          handleError(error)
        }
      }
  }

  func handleMarkWatchedToEpisode(episode: Episode, backend: BackendProtocol) {
    Task {
      do {
        episode.season.show.markWatchedUpTo(targetEpisode: episode)
        try await displayState.backend.updateSeenThru(show: episode.season.show)
      } catch {
        handleError(error)
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

          // synopsis is provided as HTML
          let data = Data(synopsis.utf8)
          let documentType = NSAttributedString.DocumentType.html
          let encoding = String.Encoding.utf8.rawValue
          let nsAttrStr = try? NSAttributedString(
            data: data,
            options: [.documentType: documentType, .characterEncoding: encoding],
            documentAttributes: nil
          )
          var attrStr = AttributedString(nsAttrStr ?? NSAttributedString())
          attrStr.font = .footnote
          summaryView = Text(attrStr)

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
  let item = NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: false)
  let season = Season(number: 1, items: [item])
  let show = Show(id: 1, title: "test", tvmazeId: "1", favorite: .unfavorited,
                  location: "Netflix", episodeLength: "60 min.", seasons: [season])
  item.season = season
  season.show = show
  return EpisodeDetailView(episode: .constant(item))
    .environment(ContentView.DisplayState(backend: BackendStub()))
    .previewLayout(.fixed(width: 50, height: 50))
    .previewDisplayName("Sheet")
}
