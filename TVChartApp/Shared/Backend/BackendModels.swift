import Foundation

struct ApiStatusUpdate: Encodable {
  let watched: [ApiEpisodeDescriptor]?
  let unwatched: [ApiEpisodeDescriptor]?
}

struct ApiEpisodeDescriptor: Encodable {
  let seasonIndex: Int
  let episodeIndex: Int

  init(from episodeDescriptor: EpisodeDescriptor) {
    self.seasonIndex = episodeDescriptor.season - 1
    self.episodeIndex = episodeDescriptor.episodeIndex
  }
}
