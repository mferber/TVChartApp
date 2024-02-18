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
          ForEach(show.seasons) { season in
            let chars = season.items.map { item -> String in
              switch item {
                case .episode(let status), .special(let status):
                  switch status {
                    case .unwatched: return "☐"
                    case .watched: return "☑︎"
                  }
                case .separator:
                  return " + "
              }
            }
            Text(String(season.id) + " " + chars.joined(separator: ""))
          }
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
