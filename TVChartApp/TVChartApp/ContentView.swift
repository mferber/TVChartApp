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
        .background(displayState.showFavoritesOnly ? .accent.opacity(0.1) : .clear)
        .navigationTitle(displayState.showFavoritesOnly ? "Favorite shows" : "All shows")
        .toolbar {
          Button {
            startTask(sendingErrorsTo: appState.errorDisplayList) {
              if let undoneCmd = try await displayState.commandExecutor.undo() {
                appState.showToast(message: "Undo: \(undoneCmd.undoDescription)")
              }
            }
          } label: {
            Text("Undo")
          }.disabled(!displayState.commandExecutor.canUndo)

          Button { } label: { Image(systemName: "arrow.trianglehead.counterclockwise") }

          FavoritesToggle(isOn: $displayState.showFavoritesOnly)
        }
      }
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

private struct FavoritesToggle: View {
  @Binding var isOn: Bool
  @Environment(TVChartApp.AppState.self) var appState
  @Environment(ContentView.DisplayState.self) var displayState

  var body: some View {
    Button {
      withAnimation {
        isOn = !isOn
        appState.showToast(message: isOn ? "Showing favorites only" : "Showing all shows")
      }
    } label: {
      Image(systemName: isOn ? "heart.fill" : "heart")
    }
  }
}

struct ShowListLoadingView: View {
  let appData: Loadable<AppData>
  let contentMarginBottom: CGFloat

  @Environment(ContentView.DisplayState.self) var displayState

  var body: some View {
    switch appData {
      case .loading:
        ProgressView()
          .controlSize(.extraLarge)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

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
              ShowListView().environment(appData)
            }
            .onChange(of: contentMarginBottom) {
              // scroll selected show to be visible
              // REGRESSION: originally we scrolled so the selected episode
              // (season), but restructuring the view hierarchy meant that
              // individual seasons are no longer the scrollview's children
              // and can't be targeted directly.
              // Possibly fixable using GeometryReader and preferences to
              // locate the selected season?
              if let descriptor = displayState.selectedEpisodeDescriptor {
                withAnimation {
                  proxy.scrollTo(descriptor.showId, anchor: .top)
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
