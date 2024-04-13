import Foundation

@Observable
class AppData {
  var shows: [Show]

  init(shows: [Show]) {
    self.shows = shows
  }

  func findEpisode(descriptor: EpisodeDescriptor) -> Episode? {
    return shows
      .first { $0.id == descriptor.showId }?
      .seasons[safe: descriptor.season - 1]?
      .items.compactMap { $0 as? Episode }
      .first { $0.episodeIndex == descriptor.episodeIndex }
  }
}
