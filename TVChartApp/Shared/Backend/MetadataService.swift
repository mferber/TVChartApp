import Foundation

protocol MetadataServiceProtocol {
  func getEpisodeMetadata(forShow show: Show, season: Int, episodeIndex: Int) async throws -> EpisodeMetadata
}

class MetadataService : MetadataServiceProtocol {
  var cache: Dictionary<Int, [[EpisodeMetadata]]> = [:]

  func getEpisodeMetadata(forShow show: Show, season: Int, episodeIndex: Int) async throws -> EpisodeMetadata {
    if let metadata = cache[show.id]?[season - 1][episodeIndex] {
      return metadata
    }
    
    let allMetadata = try await MetadataClient().fetchShowMetadata(show: show)

    var seasons: [[EpisodeMetadata]] = []
    var currentSeasonIndex = -1
    for item in allMetadata {
      if item.season != currentSeasonIndex + 1 {
        currentSeasonIndex += 1
        seasons.append([])
      }
      seasons[currentSeasonIndex].append(item)
    }
    cache[show.id] = seasons
    return seasons[season - 1][episodeIndex]  // FIXME: trap out-of-range error: stored episode list may not match tvmaze
  }
}

class MetadataServiceStub: MetadataServiceProtocol {
  func getEpisodeMetadata(forShow show: Show, season: Int, episodeIndex: Int) async throws -> EpisodeMetadata {
    let synopsis = #"<b>BoJack</b> takes an underwater trip to the <i>Pacific Ocean Film Festival</i> for the "Secretariat" premiere, where he tries to reach out to Kelsey."#
    return EpisodeMetadata(season: 3, episode: 4, title: "Fish out of Water", length: "26 min.", synopsis: synopsis)
  }
}
