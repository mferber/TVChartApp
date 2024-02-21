import Foundation

class MetadataService {
  var cache: Dictionary<String, [[EpisodeMetadata]]> = [:]

  func getEpisodeMetadata(forShow show: Show, season: Int, episodeIndex: Int) async throws -> EpisodeMetadata {
    if let metadata = cache[show.tvmazeId]?[season - 1][episodeIndex] {
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
    cache[show.tvmazeId] = seasons
    return seasons[season - 1][episodeIndex]
  }

  enum Error: Swift.Error, CustomStringConvertible {
    case outOfRange(requestedSeason: Int, lastSeason: Int)

    var description: String {
      switch self {
        case let .outOfRange(requestedSeason, lastSeason):
          "requested season \(requestedSeason) is out of bounds - last season is \(lastSeason)"
      }
    }
  }
}
