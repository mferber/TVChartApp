import Foundation
import SwiftUI

struct EpisodeDetailView: View {

  struct EpisodeIdentity: Equatable {
    let showId: Int
    let seasonNum: Int
    let index: Int

    init(_ episode: Episode) {
      self.showId = episode.season.show.id
      self.seasonNum = episode.season.number
      self.index = episode.episodeIndex
    }
  }

  @Environment(ContentView.DisplayState.self) var displayState
  @Binding var episode: Episode
  @State private var metadata: DataState<EpisodeMetadata> = .loading
  let metadataService: MetadataServiceProtocol

  func fetchMetadata(episode: Episode) {
    Task {
      do {
        metadata = .loading
        let actualMetadata = try await metadataService.getEpisodeMetadata(
          forShow: episode.season.show,
          season: episode.season.number,
          episodeIndex: episode.episodeIndex
        )
        metadata = .ready(actualMetadata)
      } catch {
        handleError(error)
      }
    }
  }

  var body: some View {
    return VStack(alignment: .leading, spacing: 0) {
      EpisodeDetailLoadableContentsView(episode: $episode, metadata: metadata)
    }
    .padding()
    .onChange(of: EpisodeIdentity(episode), initial:true) {
      fetchMetadata(episode: episode)
    }
  }
}

struct EpisodeDetailLoadableContentsView: View {
  @Binding var episode: Episode
  var metadata: DataState<EpisodeMetadata>

  var body: some View {
    switch metadata {
      case let .ready(metadata): EpisodeDetailMetadataView(episode: $episode, metadata: metadata)
      case .loading: ProgressView()
      default: EmptyView()
    }
  }
}

struct EpisodeDetailMetadataView: View {
  @Binding var episode: Episode
  let metadata: EpisodeMetadata
  @Environment(ContentView.DisplayState.self) var displayState

  private var episodeDescription: String {
    let desc: String
    switch episode {
      case let numberedEpisode as NumberedEpisode:
        desc = "episode \(numberedEpisode.episodeNumber)"
      case is SpecialEpisode:
        desc = "special"
      default:
        desc = "?"
    }
    return "\(desc) — \(metadata.length)"
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

  var body: some View {
    HStack(alignment: .top) {
      Text(metadata.title).font(.title3).fontWeight(.heavy)
      Spacer()
      Toggle("Watched", isOn: $episode.isWatched).labelsHidden()
    }
    Text(episode.season.show.title)
    Text("Season \(episode.season.number), \(episodeDescription)")
      .font(.footnote)

    SynopsisView(synopsis: metadata.synopsis)

    Button {
      handleMarkWatchedToEpisode(episode: episode, backend: displayState.backend)
    } label: {
      Text("Mark all episodes watched up to here")
        .frame(maxWidth: .infinity)
    }.buttonStyle(.borderedProminent)
      .padding([.top], 15)
  }
}

struct SynopsisView: View {
  let synopsis: String?

  var body: some View {
    var synopsisView: Text
    if let synopsis {

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
      attrStr.font = Font.footnote
      synopsisView = Text(attrStr)

    } else {
      synopsisView = Text("No summary available").italic()
    }

    return synopsisView
      .frame(maxWidth: .infinity, alignment: .leading)
      .font(.footnote)
      .padding(10)
      .padding([.leading, .trailing], 5)
      .background(Color(white: 0.97))
      .border(Color(white: 0.75))
      .padding([.top], 10)
  }
}

#Preview {
  let item = NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: false)
  let season = Season(number: 1, items: [item])
  let show = Show(id: 1, title: "Bojack Horseman", tvmazeId: "1", favorite: .unfavorited,
                  location: "Netflix", episodeLength: "60 min.", seasons: [season])
  item.season = season
  season.show = show
  return EpisodeDetailView(episode: .constant(item), metadataService: MetadataServiceStub())
    .environment(ContentView.DisplayState(backend: BackendStub()))
    .previewLayout(.fixed(width: 50, height: 50))
    .previewDisplayName("Sheet")
}
