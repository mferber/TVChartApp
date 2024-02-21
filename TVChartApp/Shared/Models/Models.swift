import Foundation

enum Status: Codable {
  case unwatched
  case watched
}

enum FavoriteStatus: Codable {
  case favorited
  case unfavorited
}

class SeasonItem: Identifiable {
  init(index: Int, kind: Kind) {
    self.index = index
    self.kind = kind
  }

  enum Kind {
    case episode(number: Int, status: Status)
    case special(status: Status)
    case separator
  }

  var id: Int { index }
  var index: Int
  var kind: Kind
  var season: Season!
}

class Season: Identifiable {
  init(number: Int, items: [SeasonItem]) {
    self.number = number
    self.items = items
  }

  var id: Int { number }
  var number: Int
  var items: [SeasonItem]
  var show: Show!
}

class Show: Codable, Identifiable {
  class SeenThru: Codable {
    init(season: Int, episodesWatched: Int) {
      self.season = season
      self.episodesWatched = episodesWatched
    }
    
    var season: Int
    var episodesWatched: Int
  }

  init(title: String, tvmazeId: String, favorite: FavoriteStatus, location: String, episodeLength: String, seasons: [Season]) {
    self.title = title
    self.tvmazeId = tvmazeId
    self.favorite = favorite
    self.location = location
    self.episodeLength = episodeLength
    self.seasons = seasons
  }

  var id: String { tvmazeId }
  var title: String
  var tvmazeId: String
  var favorite: FavoriteStatus
  var location: String
  var episodeLength: String
  var seasons: [Season]

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
    
    func watchedStatus(season: Int, episodeIndex: Int, seenThru: SeenThru) -> Status {
      if season < seenThru.season {
        return .watched
      } else if season == seenThru.season && episodeIndex < seenThru.episodesWatched {
        return .watched
      } else {
        return .unwatched
      }
    }
    
    self.seasons = seasonDescriptors.enumerated().map { (idx, descriptor) -> Season in
      let seasonNum = idx + 1
      var episodeIndex = 0, nextEpisodeNumber = 1
      
      let items = descriptor.enumerated().map { (itemIdx, charCode) -> SeasonItem? in
        let status = watchedStatus(season: seasonNum, episodeIndex: episodeIndex, seenThru: seenThru)
        var kind: SeasonItem.Kind
        switch charCode {
          case ".":
            kind = .episode(number: nextEpisodeNumber, status: status)
            nextEpisodeNumber += 1
            episodeIndex += 1
          case "S":
            kind = .special(status: status)
            episodeIndex += 1
          case "+":
            kind = .separator
          default:
            return nil
        }
        return SeasonItem(index: itemIdx, kind: kind)
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
        switch $0.kind {
          case .episode:
            return "."
          case .special:
            return "S"
          case .separator:
            return "+"
        }
      }.joined(separator: "")
    }

    try container.encode(seasons.map(encodeSeason), forKey: .seasonMaps)

    var lastWatchedSeason = 1, lastWatchedEpisodeCount = 0, episodeCounter = 0
    for (seasonIndex, season) in seasons.enumerated() {
      episodeCounter = 0
      for item in season.items {
        switch item.kind {
          case let .episode(number: _, status: status), let .special(status: status):
            episodeCounter += 1
            if status == .watched {
              lastWatchedSeason = seasonIndex + 1
              lastWatchedEpisodeCount = episodeCounter
            }
          case .separator:
            break
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
  let season: Int
  let episode: Int?
  let title: String
  let length: String
  let synopsis: String

  struct DTO: Decodable {
    let season: Int
    let number: Int?
    let name: String
    let runtime: Int?
    let summary: String

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
        synopsis: summary
      )
    }
  }
}
