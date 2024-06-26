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
    var commandExecutor: CommandExecutor
    var showFavoritesOnly = true
    var isPresentingSelectedEpisode = false
    var selectedEpisodeDescriptor: EpisodeDescriptor? = nil

    init(commandExecutor: CommandExecutor) {
      self.commandExecutor = commandExecutor
    }
  }

  @State private var loadableAppData: Loadable<AppData> = .loading
  @State private var displayState: DisplayState

  // height of the episode-details value; scroll view will be adjusted to leave room
  @State private var presentationHeight: CGFloat = 0

  @Environment(TVChartApp.AppState.self) var appState

  init(commandExecutor: CommandExecutor) {
    self._displayState = State(initialValue: DisplayState(commandExecutor: commandExecutor))
  }

  var body: some View {
    // leave a little extra room above the presentation height for the UI sheet chrome
    let contentMarginBottom = (displayState.isPresentingSelectedEpisode ?
                               presentationHeight + EpisodeBoxSpecs.size / 2.0 :
                                0)
    ZStack {
      NavigationStack {
        ShowListLoadingView(
          appData: loadableAppData,
          contentMarginBottom: contentMarginBottom
        )
        .navigationTitle(displayState.showFavoritesOnly ? "Favorite shows" : "All shows")
      }
      FavoritesToggle(isOn: $displayState.showFavoritesOnly)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
    .onPreferenceChange(EpisodeDetailViewHeightPreferenceKey.self) { prefValue in
      presentationHeight = prefValue
    }
    .task { await self.loadData() }
    .refreshable { await self.loadData() }
    .environment(displayState)
  }

  func loadData() async {
    do {
      loadableAppData = .ready(try await displayState.commandExecutor.execute(LoadData()))
    } catch {
      loadableAppData = .error(error)
      handleError(error)
    }
  }
}

struct ShowListLoadingView: View {
  let appData: Loadable<AppData>
  let contentMarginBottom: CGFloat

  @Environment(ContentView.DisplayState.self) var displayState

  var body: some View {
    switch appData {
      case .loading: ProgressView().controlSize(.extraLarge)

      case .error:
        GeometryReader { geometry in
          ScrollView {
            // center text vertically in scroll view
            ZStack {
              Spacer().frame(width: geometry.size.width, height: geometry.size.height)
              ContentUnavailableView("Can't connect", systemImage: "cloud.bolt", description: Text("Pull to refresh to try again"))
            }
          }
        }

      case .ready(let appData):
        VStack {
          ScrollViewReader { proxy in
            ScrollView([.vertical]) {
              ShowList().environment(appData)
            }
            .onChange(of: contentMarginBottom) {
              // ensure selected episode stays visible even when sheet is presented
              if let descriptor = displayState.selectedEpisodeDescriptor {
                withAnimation {
                  proxy.scrollTo(seasonRowId(showId: descriptor.showId, season: descriptor.season))
                }
              }
            }
            .defaultScrollAnchor(.topLeading)
            .scrollClipDisabled()
          }

          // This rectangle insets the show listings to make room for the presented
          // episode details sheet, so that the full listings can still be viewed
          // while the sheet is open.
          // This would be better done with contentMargins, but there's a bug where,
          // if the sheet is open and the view is scrolled to the very bottom, when
          // the sheet is closed and the contentMargins return to normal, the view
          // doesn't redraw until dragged, leaving a big empty space where the sheet
          // was. This is a workaround.
          Rectangle()
            .fill(.clear)
            .frame(minHeight: contentMarginBottom, maxHeight: contentMarginBottom)
        }
    }
  }
}

struct ShowList: View {
  @Environment(ContentView.DisplayState.self) var displayState
  @Environment(AppData.self) var appData

  var body: some View {
    let displayShows = displayState.showFavoritesOnly ? appData.shows.favoritesOnly : appData.shows
    @Bindable var displayState = displayState

    VStack(alignment: .leading, spacing: 20) {
      ForEach(displayShows) { show in
        VStack(alignment: .leading) {
          
          // Show header view id is the show title
          Text(show.title)
            .font(.title2)
            .bold()
            .padding([.leading])
            .id(show.title)

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
    .background()
    .onTapGesture { displayState.isPresentingSelectedEpisode = false }
    .sheet(
      isPresented: $displayState.isPresentingSelectedEpisode,
      onDismiss: { displayState.selectedEpisodeDescriptor = nil }
    ) {
      if let descriptor = displayState.selectedEpisodeDescriptor {
        EpisodeDetailView(episodeDescriptor: descriptor)
          .presentationDetents([.fraction(0.4), .large])
          .presentationContentInteraction(.scrolls)
          .presentationBackgroundInteraction(.enabled(upThrough: .large))
          .presentationDragIndicator(.automatic)
          .presentationBackground(.thinMaterial)
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

    // SeasonRow view id uses showId and seasonId
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
    .id(seasonRowId(showId: show.id, season: season.number))
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

private func seasonRowId(showId: Int, season: Int) -> String {
  return "\(showId).\(season)"
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

      return ContentView(commandExecutor: CommandExecutor(backend: backend, metadataService: MetadataServiceStub()))
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
