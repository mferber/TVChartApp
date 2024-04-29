import SwiftUI

struct EpisodeBoxSpecs {
  static let size = CGFloat(30.0)
  static let borderWidth = CGFloat(1.5)
  static let cornerRadius = CGFloat(10.5)
  static let font = Font.footnote
}

struct ContentView: View {

  @Observable
  class DisplayState {
    var backend: BackendProtocol
    var showFavoritesOnly = true
    var isPresentingSelectedEpisode = false
    var selectedEpisodeDescriptor: EpisodeDescriptor? = nil

    init(backend: BackendProtocol) {
      self.backend = backend
    }
  }

  @State var loadableAppData: Loadable<AppData> = .loading
  @State var displayState: DisplayState
  @Environment(TVChartApp.AppState.self) var appState

  let metadataService: MetadataServiceProtocol

  init(backend: BackendProtocol, metadataService: MetadataServiceProtocol) {
    self._displayState = State(initialValue: DisplayState(backend: backend))
    self.metadataService = metadataService
  }

  var body: some View {
    ZStack {
      NavigationStack {
        ShowListLoadingView(appData: loadableAppData, metadataService: metadataService)
          .navigationTitle("All shows")
      }
      FavoritesToggle(isOn: $displayState.showFavoritesOnly)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
    .task { await self.loadData() }
    .refreshable { await self.loadData() }
    .environment(displayState)
  }

  func loadData() async {
    do {
      loadableAppData = .ready(AppData(shows: try await displayState.backend.fetch()))
    } catch {
      loadableAppData = .error(error)
      handleError(error)
    }
  }
}

struct ShowListLoadingView: View {
  var appData: Loadable<AppData>
  var metadataService: MetadataServiceProtocol

  var body: some View {
    switch appData {
      case .loading: ProgressView().controlSize(.extraLarge)

      case .error:
        VStack {
          Text("Failed to load data").font(.body)
          Text("Pull to refresh to try again").font(.body)
        }

      case .ready(let shows): ScrollView([.vertical]) {
        ShowList(metadataService: metadataService)
          .environment(shows)
      }.defaultScrollAnchor(.topLeading)
    }
  }
}

struct ShowList: View {
  @Environment(ContentView.DisplayState.self) var displayState
  @Environment(AppData.self) var appData

  let metadataService: MetadataServiceProtocol

  var body: some View {
    let displayShows = displayState.showFavoritesOnly ? appData.shows.favoritesOnly : appData.shows
    @Bindable var displayState = displayState

    VStack(alignment: .leading, spacing: 20) {
      ForEach(displayShows) { show in
        VStack(alignment: .leading) {
          Text(show.title)
            .font(.title2)
            .bold()
            .padding([.leading])

          HStack(spacing: 5) {
            Image(systemName: show.isFavorite ? "heart.fill" : "heart")
              .foregroundColor(Color.accentColor)
            Text(show.location + ", " + show.episodeLength)
          }.padding([.leading])

          ForEach(show.seasons) {
            SeasonRow(show: show, season: $0)
          }
        }
      }
    }
    .padding([.top, .bottom])
    .sheet(
      isPresented: $displayState.isPresentingSelectedEpisode,
      onDismiss: { displayState.selectedEpisodeDescriptor = nil }
    ) {
      if let descriptor = displayState.selectedEpisodeDescriptor {
        EpisodeDetailView(
          episodeDescriptor: descriptor,
          metadataService: metadataService
        )
        .padding()
        .presentationDetents([.fraction(0.4), .large])
        .presentationContentInteraction(.scrolls)
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        .presentationDragIndicator(.automatic)
      }
      Spacer()
    }
  }
}

struct SeasonRow: View {
  let show: Show
  let season: Season
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    let maxOpacity = colorScheme == .dark ? 0.5 : 0.9
    HStack(spacing: 0) {
      Text(String(season.id))
        .bold()
        .frame(width: EpisodeBoxSpecs.size, height: EpisodeBoxSpecs.size, alignment: .trailing)
        .padding(.trailing, EpisodeBoxSpecs.size / 2.0)
        .background(
          Color(UIColor.systemBackground)
            .mask(
              LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(maxOpacity), Color.clear]),
                startPoint: .center,
                endPoint: .trailing
              )
            )
        )
        .zIndex(1)

      ScrollView([.horizontal], showsIndicators: false) {
        HStack(spacing: EpisodeBoxSpecs.size / 4.0) {
          EpisodeRow(items: season.items)
          SeasonEnd(filled: season.isCompleted)
        }
      }
      .defaultScrollAnchor(.leading)
      .scrollClipDisabled()  // permit scrolling behind season numbers
    }
  }
}

struct EpisodeRow: View {
  let items: [SeasonItem]

  var body: some View {
    HStack(spacing: EpisodeBoxSpecs.size / 8.0) {
      ForEach(items) { item in
        switch item {
          case let episode as Episode:
            EpisodeButton(episode: episode)
          case is Separator:
            SeparatorView()
          default:
            EmptyView()
        }
      }
    }
  }
}

struct SeasonEnd: View {
  var filled: Bool

  var body: some View {
    return Image(systemName: "rhombus\(filled ? ".fill" : "")")
      .foregroundStyle(.episodeBox).dynamicTypeSize(.xSmall)
  }
}

struct EpisodeButton: View {
  let episode: Episode
  @Environment(ContentView.DisplayState.self) var displayState

  var body: some View {
    Button {
      displayState.selectedEpisodeDescriptor = episode.descriptor
      displayState.isPresentingSelectedEpisode = true
    } label: {
      EpisodeView(
        episode: episode,
        isSelected: displayState.selectedEpisodeDescriptor?.matches(episode) ?? false
      )
    }
  }
}

struct EpisodeView: View {
  let episode: Episode
  let isSelected: Bool

  var body: some View {
    let caption: AnyView
    if let numbered = episode as? NumberedEpisode {
      caption = AnyView(Text(String(numbered.episodeNumber)).font(EpisodeBoxSpecs.font))

    } else {
      caption = AnyView(Image(systemName: "star.fill").font(EpisodeBoxSpecs.font))
    }

    return ZStack {
      EpisodeBox(episode: episode, isSelected: isSelected)
      EpisodeLabel(episode: episode, caption: caption, isSelected: isSelected)
    }
    .animation(.easeInOut.speed(3), value: episode.isWatched)
    .animation(.easeInOut.speed(3), value: isSelected)
  }
}

struct EpisodeBox: View {
  let episode: Episode
  let isSelected: Bool

  var body: some View {
   let strokeColor: Color, fillColor: Color

    switch (episode.isWatched, isSelected) {
      case (false, false): 
        strokeColor = .episodeBox
        fillColor = .clear
      case (true, false):
        strokeColor = .episodeBox
        fillColor = .episodeBox
      case (false, true):
        strokeColor = .accentColor
        fillColor = .clear
      case (true, true):
        strokeColor = .accentColor
        fillColor = .accentColor
    }

    return RoundedRectangle(cornerRadius: EpisodeBoxSpecs.cornerRadius, style: .circular)
      .fill(fillColor)
      .strokeBorder(strokeColor, lineWidth: EpisodeBoxSpecs.borderWidth)
      .frame(width: EpisodeBoxSpecs.size, height: EpisodeBoxSpecs.size)
  }
}

struct EpisodeLabel: View {
  let episode: Episode
  let caption: AnyView
  let isSelected: Bool

  var body: some View {
    let fgColor: Color
    switch (episode.isWatched, isSelected) {
      case (true, _): fgColor = .watchedText
      case (false, true): fgColor = .accentColor
      case (false, false): fgColor = .unwatchedText
    }
    
    return caption.foregroundColor(fgColor)
  }
}

struct SeparatorView: View {
  var body: some View {
    Image(systemName: "plus")
      .imageScale(.small)
      .foregroundColor(.episodeBox)
      .frame(width: EpisodeBoxSpecs.size / 2.0, height: EpisodeBoxSpecs.size / 2.0)
  }
}

struct FavoritesToggle: View {
  @Binding var isOn: Bool
  @Environment(ContentView.DisplayState.self) var displayState

  var body: some View {
    Toggle(isOn: Bindable(displayState).showFavoritesOnly) { }
      .labelsHidden()
      .padding(20)
      .background(Color.white.opacity(0.5))
      .clipped(antialiased: false)
      .cornerRadius(20.0)
  }
}

// MARK: - Previews

#if DEBUG
@MainActor
private func previewData() throws -> [Show] {
  let sampleDataUrl = Bundle.main.url(forResource: "previewData", withExtension: "json")
  guard let sampleDataUrl else {
    throw TVChartError.general("no URL to sample data")
  }
  let json = try? Data(contentsOf: sampleDataUrl)
  guard let json else {
    throw TVChartError.general("can't read sample data")
  }
  var content: [Show]!
  do {
    try content = JSONDecoder().decode([ShowDTO].self, from: json).map { $0.toShow() }
  } catch {
    throw TVChartError.general("can't parse JSON: \(error)")
  }
  return content.sortedByTitle
}
#endif

#Preview {
    do {
      var shows: [Show] = []
      try MainActor.assumeIsolated {
        shows = try previewData()
      }
      let backend = BackendStub()
      backend.fetchResult = shows

      return ContentView(backend: backend, metadataService: MetadataServiceStub())
        .environment(TVChartApp.AppState())
        .tint(.accent)

    } catch {
      let desc = switch error {
      case let e as DisplayableError: e.displayDescription
      default: "\(error)"
      }
      print(desc)
      return Text(desc)
    }

}
