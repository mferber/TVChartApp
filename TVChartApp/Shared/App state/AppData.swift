import Foundation

enum DataState<T> {
  case loading
  case ready(T)
  case error(Error)
}

@Observable
class AppData {
  var shows: DataState<[Show]>

  init() {
    self.shows = .loading
  }

  init(shows: [Show]) {
    self.shows = .ready(shows)
  }
}


