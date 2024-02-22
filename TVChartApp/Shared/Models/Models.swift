import Foundation

enum FavoriteStatus: Codable {
  case favorited
  case unfavorited
}

class SeasonItem: Identifiable {
  var id: Int { index }
  let index: Int
  var season: Season!

  fileprivate init(index: Int) {
    self.index = index
  }
}

class Episode: SeasonItem {
  // 0-based, episode counter (ignoring separators) -- may be able to get rid of this when
  // the seenThru construct goes away and we don't need to count episodes anymore
  let episodeIndex: Int
  var isWatched: Bool

  fileprivate init(index: Int, episodeIndex: Int, isWatched: Bool) {
    self.episodeIndex = episodeIndex
    self.isWatched = isWatched
    
    super.init(index: index)
  }
}

class NumberedEpisode: Episode {
  let episodeNumber: Int  // official episode number

  init(index: Int, episodeIndex: Int, episodeNumber: Int, isWatched: Bool) {
    self.episodeNumber = episodeNumber

    super.init(index: index, episodeIndex: episodeIndex, isWatched: isWatched)
  }
}

class SpecialEpisode: Episode {
  override init(index: Int, episodeIndex: Int, isWatched: Bool) {
    super.init(index: index, episodeIndex: episodeIndex, isWatched: isWatched)
  }
}

class Separator: SeasonItem {
  override init(index: Int) {
    super.init(index: index)
  }
}

class Season: Identifiable {
  var id: Int { number }
  var number: Int
  var items: [SeasonItem]
  var show: Show!

  init(number: Int, items: [SeasonItem]) {
    self.number = number
    self.items = items
  }
}

class Show: Codable, Identifiable {
  // SeenThru is an artifact of the old data model, which will hopefully be discarded soon
  // in favor of tracking watched status at the individual episode level
  class SeenThru: Codable {
    init(season: Int, episodesWatched: Int) {
      self.season = season
      self.episodesWatched = episodesWatched
    }
    
    var season: Int
    var episodesWatched: Int
  }

  var id: String { tvmazeId }
  var title: String
  var tvmazeId: String
  var favorite: FavoriteStatus
  var location: String
  var episodeLength: String
  var seasons: [Season]

  init(title: String, tvmazeId: String, favorite: FavoriteStatus, location: String, episodeLength: String, seasons: [Season]) {
    self.title = title
    self.tvmazeId = tvmazeId
    self.favorite = favorite
    self.location = location
    self.episodeLength = episodeLength
    self.seasons = seasons
  }

  enum CodingKeys: String, CodingKey {
    case id
    case title
    case tvmazeId
    case favorite
    case location
    case length
    case seasonMaps
    case seenThru
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.title = try container.decode(String.self, forKey: .title)
    self.tvmazeId = try container.decode(String.self, forKey: .tvmazeId)
    self.location = try container.decode(String.self, forKey: .location)
    self.episodeLength = try container.decode(String.self, forKey: .length)
    
    let boolFavorite = try container.decode(Bool.self, forKey: .favorite)
    self.favorite = boolFavorite ? .favorited : .unfavorited
    
    let seasonDescriptors = try container.decode([String].self, forKey: .seasonMaps)
    let seenThru = try container.decode(SeenThru.self, forKey: .seenThru)
    
    // Temporary: the server-side data model currently tracks only the latest episode
    // that has been watched. Until the server-side model has adopted tracking watched
    // status on an episode-by-episode basis, this helper bridges that gap.
    func hasEpisodeBeenWatched(season: Int, episodeIndex: Int, seenThru: SeenThru) -> Bool {
      return season < seenThru.season || (season == seenThru.season && episodeIndex < seenThru.episodesWatched)
    }
    
    self.seasons = seasonDescriptors.enumerated().map { (idx, descriptor) -> Season in
      let seasonNum = idx + 1
      var episodeIndex = 0, nextEpisodeNumber = 1
      
      // decode a string of characters, each representing one season item
      // . = numbered episode
      // S = special episode
      // + = separator
      let items = descriptor.enumerated().map { (itemIdx, charCode) -> SeasonItem? in
        
        switch charCode {
            
          case ".":
            let episode = NumberedEpisode(
              index: itemIdx,
              episodeIndex: episodeIndex,
              episodeNumber: nextEpisodeNumber,
              isWatched: hasEpisodeBeenWatched(season: seasonNum, episodeIndex: episodeIndex, seenThru: seenThru)
            )
            nextEpisodeNumber += 1
            episodeIndex += 1
            return episode

          case "S":
            let episode = SpecialEpisode(
              index: itemIdx,
              episodeIndex: episodeIndex,
              isWatched: hasEpisodeBeenWatched(season: seasonNum, episodeIndex: episodeIndex, seenThru: seenThru)
            )
            episodeIndex += 1
            return episode

          case "+":
            return Separator(index: itemIdx)

          default:
            return nil
        }
      }.compactMap({ $0 })
      return Season(number: idx + 1, items: items)
    }

    for season in self.seasons {
      for item in season.items {
        item.season = season
      }
      season.show = self
    }
  }

  // FIXME: do we even need encoding?
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(title, forKey: .title)
    try container.encode(tvmazeId, forKey: .tvmazeId)

    if case .favorited = favorite {
      try container.encode(true, forKey: .favorite)
    } else {
      try container.encode(false, forKey: .favorite)
    }

    try container.encode(location, forKey: .location)
    try container.encode(episodeLength, forKey: .length)

    func encodeSeason(season: Season) -> String {
      return season.items.map {
        switch $0 {
          case is NumberedEpisode:
            return "."
          case is SpecialEpisode:
            return "S"
          case is Separator:
            return "+"
          default:
            return ""
        }
      }.joined(separator: "")
    }

    try container.encode(seasons.map(encodeSeason), forKey: .seasonMaps)

    // Temporary: determine the latest watched episode; the server-side data model only
    // tracks that. This can go when the server-side model has been updated to track
    // watched episodes on an individual basis.
    var lastWatchedSeason = 1, lastWatchedEpisodeCount = 0, episodeCounter = 0
    for (seasonIndex, season) in seasons.enumerated() {
      episodeCounter = 0
      for item in season.items {
        if let episode = item as? Episode {
          episodeCounter += 1
          if episode.isWatched {
            lastWatchedSeason = seasonIndex + 1
            lastWatchedEpisodeCount = episodeCounter
          }
        }
      }
    }
    let seenThru = SeenThru(season: lastWatchedSeason, episodesWatched: lastWatchedEpisodeCount)
    try container.encode(seenThru, forKey: .seenThru)
  }
}

extension [Show] {
  var sortedByTitle: [Show] {
    let leadingArticlePat = /^(a|an|the)\s+/.ignoresCase()
    return self
      .map { ($0.title.replacing(leadingArticlePat, with: ""), $0) }
      .sorted { $0.0 < $1.0 }
      .map { $0.1 }
  }
}

struct EpisodeMetadata {
  struct DTO: Decodable {
    let season: Int
    let number: Int?
    let name: String
    let runtime: Int?
    let summary: String?

    func toDomain() -> EpisodeMetadata {
      let length: String
      if let runtime {
        length = "\(runtime) min."
      } else {
        length = "n/a"
      }
      
      return EpisodeMetadata(
        season: season,
        episode: number,
        title: name,
        length: length,
        synopsis: summary?.paragraphContainerStripped
      )
    }
  }

  let season: Int
  let episode: Int?
  let title: String
  let length: String
  let synopsis: String?
}

private extension String {
  var paragraphContainerStripped: String {
    self.replacing(#/^<p>|</p>$/#, with: "")
  }
}
