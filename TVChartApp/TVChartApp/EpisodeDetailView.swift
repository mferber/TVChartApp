import Foundation
import SwiftUI

enum EpisodeDetailError: DisplayableError {
  case invalidEpisodeDescriptor

  var displayDescription: String {
    switch self {
      case .invalidEpisodeDescriptor:
        return "Selected episode doesn't exist"
    }
  }

  var displayDetails: String? { nil }
}

// State: episode descriptor
// Requires metadata service to look up episode details
struct EpisodeDetailView: View {
  let episodeDescriptor: EpisodeDescriptor
  let metadataService: MetadataServiceProtocol

  @State private var episode: Episode?
  @State private var loadableMetadata: Loadable<EpisodeMetadata> = .loading

  @Environment(AppData.self) private var appData
  @Environment(ContentView.DisplayState.self) private var displayState
  @Environment(TVChartApp.AppState.self) private var appState

  func fetchMetadata() {
    Task {
      do {
        loadableMetadata = .loading

        guard let episode else {
          loadableMetadata = .error(EpisodeDetailError.invalidEpisodeDescriptor)
          return
        }

        loadableMetadata = .ready(
          try await metadataService.getEpisodeMetadata(
            forShow: episode.season.show,
            season: episode.season.number,
            episodeIndex: episode.episodeIndex
          )
        )
      } catch {
        loadableMetadata = .error(error)
        displayState.isPresentingSelectedEpisode = false
        withAnimation {
          appState.errorDisplayList.add(error)
        }
      }
    }
  }

  var body: some View {
    Group {
      if let episode {
        VStack(alignment: .leading, spacing: 0) {
          EpisodeDetailMetadataLoadingView(episode: episode, loadableMetadata: loadableMetadata)
        }
      } else {
        Text("Selected episode not found")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .onChange(of: episodeDescriptor, initial: true) {
      Task {
        // user selected a different episode in the main view
        episode = await appData.findEpisode(descriptor: episodeDescriptor)
        if episode != nil {
          fetchMetadata()
        }
      }
    }
  }
}

// Displays loading indicator till metadata is ready
struct EpisodeDetailMetadataLoadingView: View {
  var episode: Episode
  var loadableMetadata: Loadable<EpisodeMetadata>

  @Environment(TVChartApp.AppState.self) var appState

  var body: some View {
    Group {
      switch loadableMetadata {
        case let .ready(metadata):
          EpisodeDetailMetadataView(episode: episode, metadata: metadata)
        case .loading:
          ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
          EmptyView()
      }
    }
  }
}

// Displays episode metadata
struct EpisodeDetailMetadataView: View {
  @Bindable var episode: Episode
  var metadata: EpisodeMetadata

  @Environment(TVChartApp.AppState.self) var appState
  @Environment(ContentView.DisplayState.self) var displayState

  @MainActor
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
        let updatedEpisodes = await episode.season.show.markWatchedUpTo(targetEpisode: episode)
        try await backend.updateEpisodeStatuses(
          watched: updatedEpisodes,
          unwatched: []
        )
      } catch {
        withAnimation {
          appState.errorDisplayList.add(error)
        }
      }
    }
  }

  var body: some View {
    HStack(alignment: .top) {
      Text(metadata.title).font(.title3).fontWeight(.heavy)
      Spacer()
      Toggle("Watched", isOn: $episode.isWatched).labelsHidden()
        .onChange(of: episode.isWatched) { (old, new) in
          Task {
            do {
              try await displayState.backend.updateEpisodeStatus(episode: episode, watched: new)
            } catch {
              withAnimation {
                appState.errorDisplayList.add(error)
              }
            }
          }
        }
    }
    Text(episode.season.show.title)
    Text("Season \(episode.season.number), \(episodeDescription)")
      .font(.footnote)

    SynopsisView(synopsisHtml: metadata.synopsis)
      .padding([.top], 10)

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
  let synopsisHtml: String?

  @State private var parsed: AttributedString? = nil

  func displayableText() -> Text {
    guard let _ = synopsisHtml else {
      return Text("No description available").font(.system(size: 15)).italic()
    }
    guard let parsed else {  // currently parsing
      return Text("")
    }
    return Text(parsed)
  }

  var body: some View {
    Group {
      ScrollView([.vertical], showsIndicators: true) {
        displayableText()
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding([.leading, .trailing], 10)
          .padding([.top, .bottom], 5)
          .background(.clear)
          .padding([.top, .bottom], 5)
      }
      .scrollIndicators(.visible)
      .background(.ultraThinMaterial)
      .background(.synopsisBackground.opacity(0.7))
    }
    .onChange(of: synopsisHtml, initial: true) {
      Task {
        parsed = nil
        let newParsed = await synopsisHtml?.parseSynopsisHtml()
        parsed = newParsed
      }
    }
  }
}



#Preview {
  let items = [
    NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: false),
    NumberedEpisode(index: 0, episodeIndex: 1, episodeNumber: 2, isWatched: false),
    NumberedEpisode(index: 0, episodeIndex: 2, episodeNumber: 3, isWatched: false)
  ]
  let season = Season(number: 1, items: items)
  let show = Show(id: 1, title: "Bojack Horseman", tvmazeId: "1", favorite: .unfavorited,
                  location: "Netflix", episodeLength: "60 min.", seasons: [season])
  for item in items {
    item.season = season
  }
  season.show = show

  return VStack {
    EpisodeDetailView(
      episodeDescriptor: EpisodeDescriptor(showId: 1, season: 1, episodeIndex: 0),
      metadataService: MetadataServiceStub()
    )
    .tint(.accent)
    .padding()
    .environment(TVChartApp.AppState())
    .environment(ContentView.DisplayState(backend: BackendStub()))
    .environment(AppData(shows: [show]))
  }
}
