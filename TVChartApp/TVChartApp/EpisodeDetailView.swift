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
        let _ = try await backend.updateEpisodeStatus(
          show: episode.season.show,
          watched: updatedEpisodes,
          unwatched: nil
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
    }
    Text(episode.season.show.title)
    Text("Season \(episode.season.number), \(episodeDescription)")
      .font(.footnote)

    SynopsisView(synopsis: metadata.synopsis?.parseHtml())
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
  let synopsis: String?

  var body: some View {
    ScrollView([.vertical], showsIndicators: true) {
      SynopsisText(synopsis: synopsis)
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.leading, .trailing], 10)
        .padding([.top, .bottom], 5)
        .background(.clear)
        .padding([.top, .bottom], 5)
    }
    .scrollIndicators(.visible)
    .background(.synopsisBackground)
  }
}

struct SynopsisText: View {
  let synopsis: String?

  var body: some View {
    if let synopsis {
      Text(synopsis)
    } else {
      Text("No description available").italic()
    }
  }
}

extension String {
  fileprivate func parseHtml() -> String {
    // Ideally this parses an AttributedString out of HTML more or less as follows:
    //
    //  let data = Data(html.utf8)
    //  let documentType = NSAttributedString.DocumentType.html
    //  let encoding = String.Encoding.utf8.rawValue
    //  if let nsAS = try? NSAttributedString(
    //    data: data,
    //    options: [.documentType: documentType, .characterEncoding: encoding],
    //    documentAttributes: nil
    //  ) {
    //    return AttributedString(nsAS)
    //  } else {
    //    return nil
    //  }
    //
    // However, this currently fails (iOS 17), because the call to the NSAttributedString
    // initializer -- even if ignored -- causes an "AttributeGraph: cycle detected in
    // attribute..." error, and in some cases prevents the view from being reevaluated going
    // forward, causing display bugs.
    //
    // The cause is mysterious. It's specific to html decoding; if documentType is set to
    // plain, the problem disappears. The issue is attested a few times on the Internet, with
    // no solutions I could find:
    // https://www.google.com/search?q=%22nsattributedstring%22+%22html%22+%22cycle+detected%22

    // Workaround: just replace the newlines, which are the most common (only?) case where
    // it matters
    return self.replacing(#/</?(br|p)\s*/?>/#, with: "\n")
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
