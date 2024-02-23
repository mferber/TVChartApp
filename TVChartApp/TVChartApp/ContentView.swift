import SwiftUI

struct EpisodeBoxSpecs {
  static let size = CGFloat(30.0)
  static let borderWidth = CGFloat(1.5)
  static let cornerRadius = CGFloat(10.5)
  static let watchedColor = Color(white: 0.25)
  static let unwatchedColor = Color(white: 0.5)
  static let selectedColor = Color.red
  static let watchedTextColor = Color.black
  static let unwatchedTextColor = Color.white
  static let font = Font.footnote
}

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
          .presentationDetents([.fraction(0.4), .large])
          .presentationDragIndicator(.automatic)
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
    let fgColor: Color
    switch (episode.isWatched, isSelected) {
      case (false, false): fgColor = EpisodeBoxSpecs.unwatchedColor
      case (true, false): fgColor = EpisodeBoxSpecs.watchedColor
      case (_, true): fgColor = EpisodeBoxSpecs.selectedColor
    }

    return RoundedRectangle(cornerRadius: EpisodeBoxSpecs.cornerRadius, style: .circular)
      .strokeBorder(fgColor, lineWidth: EpisodeBoxSpecs.borderWidth)
      .fill(episode.isWatched ? fgColor : .clear)
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
      case (true, _): fgColor = .white
      case (false, true): fgColor = EpisodeBoxSpecs.selectedColor
      case (false, false): fgColor = .black
    }
    
    return caption.foregroundColor(fgColor)
  }
}

struct SeparatorView: View {
  var body: some View {
    Image(systemName: "plus")
      .imageScale(.small)
      .foregroundColor(EpisodeBoxSpecs.watchedColor)
      .frame(width: EpisodeBoxSpecs.size / 2.0, height: EpisodeBoxSpecs.size / 2.0)
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
