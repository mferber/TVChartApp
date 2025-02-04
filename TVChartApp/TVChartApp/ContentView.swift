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
      // the UI will show an appropriate placeholder, so don't funnel this to the error display mechanism
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
