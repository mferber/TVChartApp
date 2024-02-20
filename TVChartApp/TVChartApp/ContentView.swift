import SwiftUI

let episodeWidth = CGFloat(21.0)
let watchedColor = Color(white: 0.25)
let unwatchedColor = Color(white: 0.5)
let specialEpCaption = "⭑"

struct ContentView: View {
  var appData: AppData

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
            SeasonRow(season: $0)
          }
        }
      }
    }.padding()
  }
}

struct SeasonRow: View {
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
                EpisodeView(seasonItem: item)
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
  let seasonItem: SeasonItem

  var body: some View {
    Button {
      // FIXME: update the binding somehow
    } label: {
      switch (seasonItem.kind) {
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
        case .separator:  // shouldn't be here
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


#Preview {
  func errContent(_ msg: String) -> some View {
    return Text(msg)
  }

  let sampleDataUrl = Bundle.main.url(forResource: "previewData", withExtension: "json")
  guard let sampleDataUrl else {
    return errContent("no URL to sample data")
  }
  let json = try? Data(contentsOf: sampleDataUrl)
  guard let json else {
    return errContent("can't read sample data")
  }
  let content = try? JSONDecoder().decode([Show].self, from: json)
  guard let content else {
    return errContent("can't parse JSON")
  }
  let appData = AppData(shows: content.sortedByTitle)
  return ContentView(appData: appData)
}
