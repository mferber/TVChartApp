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
    init(backend: BackendProtocol) {
      self.backend = backend
    }

    var backend: BackendProtocol
    var showFavoritesOnly = true
    var selectedEpisode: Episode?
    var isShowingEpisodeDetail = false
  }

  var appData: AppData
  let backend: BackendProtocol
  let metadataService: MetadataServiceProtocol
  @State var displayState: DisplayState
  @Environment(TVChartApp.AppState.self) var appState

  init(appData: AppData, backend: BackendProtocol, metadataService: MetadataServiceProtocol) {
    self.appData = appData
    self.backend = backend
    self.metadataService = metadataService
    self._displayState = State(initialValue: DisplayState(backend: backend))
  }

  var body: some View {
    ZStack {
      NavigationStack {
        LoadableShowList(appData: appData).navigationTitle("All shows")
      }
      FavoritesToggle(isOn: $displayState.showFavoritesOnly)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

    }
    .sheet(
      isPresented: $displayState.isShowingEpisodeDetail,
      onDismiss: { displayState.selectedEpisode = nil }
    ) {
      if displayState.selectedEpisode != nil {
        EpisodeDetailView(
          episode: Binding($displayState.selectedEpisode)!,
          metadataService: metadataService
        )
        .presentationDetents([.fraction(0.4), .large])
        .presentationDragIndicator(.automatic)
        .presentationBackgroundInteraction(.enabled)
      }
    }
    .environment(displayState)
    .task(self.load)
    .refreshable(action: self.load)
  }

  @Sendable
  func load() async {
    do {
      try await backend.refetch()
    } catch {
      withAnimation {
        appState.errorDisplayList.add(error)
        appData.shows = .error(error)
      }
    }
  }
}

struct LoadableShowList: View {
  var appData: AppData

  var body: some View {
    switch appData.shows {
      case .loading: ProgressView().controlSize(.extraLarge)

      case .error:
        VStack {
          Text("Failed to load data").font(.body)
          Text("Pull to refresh to try again").font(.body)
        }

      case .ready(let shows): ScrollView([.vertical]) {
        ShowList(shows: shows)
      }.defaultScrollAnchor(.topLeading)
    }
  }
}

struct ShowList: View {
  @Environment(ContentView.DisplayState.self) var displayState
  let shows: [Show]

  var body: some View {
    let displayShows = displayState.showFavoritesOnly ? shows.favoritesOnly : shows

    VStack(alignment: .leading, spacing: 20) {
      ForEach(displayShows) { show in
        VStack(alignment: .leading) {
          Text(show.title).font(.title2).bold()

          HStack(spacing: 5) {
            Image(systemName: show.isFavorite ? "heart.fill" : "heart")
              .foregroundColor(Color.accentColor)
            Text(show.location + ", " + show.episodeLength)
          }

          ForEach(show.seasons) {
            SeasonRow(show: show, season: $0)
          }
        }
      }
    }.padding([.leading, .top, .bottom])
  }
}

struct SeasonRow: View {
  let show: Show
  let season: Season

  var body: some View {
    HStack(spacing: 0) {
      Text(String(season.id))
        .frame(width: EpisodeBoxSpecs.size, alignment: .trailing)
        .padding(.trailing, EpisodeBoxSpecs.size / 2.0)

      ScrollView([.horizontal], showsIndicators: false) {
        HStack(spacing: EpisodeBoxSpecs.size / 8.0) {
          ForEach(season.items) { item in
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
      }.defaultScrollAnchor(.leading)
    }
  }
}

struct EpisodeButton: View {
  let episode: Episode
  @Environment(ContentView.DisplayState.self) var displayState

  var body: some View {
    Button {
      displayState.selectedEpisode = episode
      displayState.isShowingEpisodeDetail = true
    } label: {
      EpisodeView(episode: episode, isSelected: episode === displayState.selectedEpisode)
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

private func previewData() throws -> AppData {
  let sampleDataUrl = Bundle.main.url(forResource: "previewData", withExtension: "json")
  guard let sampleDataUrl else {
    throw TVChartError.general("no URL to sample data")
  }
  let json = try? Data(contentsOf: sampleDataUrl)
  guard let json else {
    throw TVChartError.general("can't read sample data")
  }
  let content = try? JSONDecoder().decode([Show].self, from: json)
  guard let content else {
    throw TVChartError.general("can't parse JSON")
  }
  return AppData(shows: content.sortedByTitle)
}

private func createPreview(_ closure: (AppData) -> any View) -> any View {
  let v: any View
  do {
    let data = try previewData()
    v = closure(data)
  } catch TVChartError.general(let msg) {
    v = Text(msg ?? "error")
  } catch {
    v = Text("error")
  }
  return v
}


#Preview {
  createPreview { appData in
    ContentView(appData: appData, backend: BackendStub(), metadataService: MetadataServiceStub())
      .environment(TVChartApp.AppState())
      .tint(.accent)
  }
}
