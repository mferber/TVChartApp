import SwiftUI

struct ContentView: View {
  var appData: AppData

  var body: some View {
    NavigationStack {
      ScrollView {
        switch appData.shows {
          case .loading: Text("loading...")
          case .error(let e): Text("error: \(e.localizedDescription)")
          case .ready(let shows): ShowList(shows: shows)
        }
      }.navigationTitle("All shows")
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
    }
  }
}

struct SeasonRow: View {
  let season: Season

  let episodeWidth = 17
  let watchedColor = Color(white: 0.25)
  let unwatchedColor = Color(white: 0.5)

  var body: some View {
    HStack(spacing: 0) {
      Text(String(season.id)).frame(width: CGFloat(episodeWidth))
      
      ForEach(season.items) { item in
        switch item.kind {
          case .episode(let status), .special(let status):
            switch status {
              case .unwatched:
                Image(systemName: "square")
                  .foregroundColor(unwatchedColor)
                  .frame(width: CGFloat(episodeWidth))
              case .watched:
                Image(systemName: "square.fill")
                  .foregroundColor(watchedColor)
                  .frame(width: CGFloat(episodeWidth))
            }
          case .separator: Image(systemName: "plus").frame(width: CGFloat(episodeWidth))
        }
      }
    }
  }
}

#Preview {
  func errContent(_ msg: String) -> some View {
    return Text(msg)
  }

  let sampleDataUrl = Bundle.main.url(forResource: "sampleData", withExtension: "json")
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
  let appData = AppData(shows: content)
  return ContentView(appData: appData)
}
