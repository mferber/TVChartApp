import SwiftUI

let episodeWidth = CGFloat(21.0)
let watchedColor = Color(white: 0.25)
let unwatchedColor = Color(white: 0.5)
let selectionColor = Color.red
let specialEpCaption = "⭑"

struct ContentView: View {

  @Observable
  class DisplayState {
    init(backend: BackendProtocol) {
      self.backend = backend
    }

    var isShowingEpisodeDetail = false
    var selectedEpisode: Episode?
    var backend: BackendProtocol
  }

  var appData: AppData
  let backend: BackendProtocol
  @State var displayState: DisplayState

  init(appData: AppData, backend: BackendProtocol) {
    self.appData = appData
    self.backend = backend
    self._displayState = State(initialValue: DisplayState(backend: backend))
  }

  var body: some View {
    NavigationStack {
      ScrollView([.vertical]) {
        switch appData.shows {
          case .loading: Text("loading...")
          case .error(let e): Text("error: \(e.localizedDescription)")
          case .ready(let shows): ShowList(shows: shows)
        }
      }
      .defaultScrollAnchor(.topLeading)
      .navigationTitle("All shows")
    }
    .sheet(
      isPresented: $displayState.isShowingEpisodeDetail,
      onDismiss: {
        displayState.selectedEpisode = nil
      }
    ) {
      if displayState.selectedEpisode != nil {
        EpisodeDetailView(episode: Binding($displayState.selectedEpisode)!)
          .presentationDetents([.fraction(0.4)])
      }
    }
    .environment(displayState)
  }
}

struct ShowList: View {
  let shows: [Show]

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      ForEach(shows) { show in
        VStack(alignment: .leading) {
          Text(show.title).font(.title2).bold()

          HStack(spacing: 5) {
            if show.favorite == .favorited {
              Image(systemName: "heart.fill").foregroundColor(.red)
            }
            Text(show.location + ", " + show.episodeLength)
          }

          ForEach(show.seasons) {
            SeasonRow(show: show, season: $0)
          }
        }
      }
    }.padding()
  }
}

struct SeasonRow: View {
  let show: Show
  let season: Season

  var body: some View {
    HStack(spacing: 0) {
      Text(String(season.id))
        .frame(width: episodeWidth * 1.5, alignment: .trailing)
        .padding(.trailing, episodeWidth / 2.0)

      ScrollView([.horizontal]) {
        HStack(spacing: 0) {
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
      }
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
    let caption: String
    if let numbered = episode as? NumberedEpisode {
      caption = String(numbered.episodeNumber)
    } else {
      caption = specialEpCaption
    }

    return ZStack {
      EpisodeBox(episode: episode, isSelected: isSelected)
      EpisodeLabel(episode: episode, caption: caption)
    }.animation(.easeInOut.speed(2), value: episode.isWatched)
  }
}

struct EpisodeBox: View {
  let episode: Episode
  let isSelected: Bool

  var body: some View {
    let symbolName = episode.isWatched ? "square.fill" : "square"

    let fgColor: Color
    switch (episode.isWatched, isSelected) {
      case (false, false): fgColor = unwatchedColor
      case (true, false): fgColor = watchedColor
      case (_, true): fgColor = selectionColor
    }

    return Image(systemName: symbolName)
      .imageScale(.large)
      .foregroundColor(fgColor)
      .frame(width: episodeWidth)
  }
}

struct EpisodeLabel: View {
  let episode: Episode
  let caption: String

  var body: some View {
    Text(caption)
      .font(.caption2)
      .foregroundColor(episode.isWatched ? Color.white : Color.black)
  }
}

struct SeparatorView: View {
  var body: some View {
    Image(systemName: "plus")
      .imageScale(.small)
      .foregroundColor(unwatchedColor)
      .frame(width: episodeWidth)
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
    ContentView(appData: appData, backend: BackendStub())
  }
}
