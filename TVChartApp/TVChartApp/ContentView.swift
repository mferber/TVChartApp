import SwiftUI

let episodeWidth = CGFloat(21.0)
let watchedColor = Color(white: 0.25)
let unwatchedColor = Color(white: 0.5)
let specialEpCaption = "⭑"

struct ContentView: View {
  @Observable
  class DisplayState {
    var isShowingEpisodeDetail = false
    var selectedItem: SeasonItem!
  }

  var appData: AppData
  @State var overallState: DisplayState = DisplayState()

  var body: some View {
    NavigationStack {
      ScrollView([.vertical]) {
        switch appData.shows {
          case .loading: Text("loading...")
          case .error(let e): Text("error: \(e.localizedDescription)")
          case .ready(let shows): ShowList(shows: shows)
        }
      } .defaultScrollAnchor(.topLeading)
        .navigationTitle("All shows")
    }
    .sheet(isPresented: $overallState.isShowingEpisodeDetail) {
      EpisodeDetailView(episode: $overallState.selectedItem)
        .presentationDetents([.fraction(0.4)])
    }
    .environment(overallState)
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
            switch item.kind {
              case .episode, .special:
                EpisodeView(item: item)
              case .separator:
                Separator()
            }
          }
        }
      }
    }
  }
}

struct EpisodeView: View {
  let item: SeasonItem
  @Environment(ContentView.DisplayState.self) var overallState

  var body: some View {
    Button {
      overallState.selectedItem = item
      overallState.isShowingEpisodeDetail = true
    } label: {
      switch (item.kind) {
        case let .episode(number, status):
          ZStack {
            EpisodeBox(status: status)
            EpisodeLabel(status: status, caption: String(number))
          }
        case let .special(status: status):
          ZStack {
            EpisodeBox(status: status)
            EpisodeLabel(status: status, caption: specialEpCaption)
          }
        case .separator:  // shouldn't get here
          EmptyView()
      }
    }
  }
}

struct EpisodeBox: View {
  let status: Status

  var body: some View {
    switch status {
      case .unwatched:
        Image(systemName: "square")
          .imageScale(.large)
          .foregroundColor(unwatchedColor)
          .frame(width: episodeWidth)

      case .watched:
        Image(systemName: "square.fill")
          .imageScale(.large)
          .foregroundColor(watchedColor)
          .frame(width: episodeWidth)
    }
  }
}

struct EpisodeLabel: View {
  let status: Status
  let caption: String

  var color: Color {
    switch status {
      case .unwatched: Color.black
      case .watched: Color.white
    }
  }

  var body: some View {
    Text(caption)
      .font(.caption2)
      .foregroundColor(color)
  }
}

struct Separator: View {
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
    ContentView(appData: appData)
  }
}
