import Foundation

enum Status: Codable {
  case unwatched
  case watched
}

enum FavoriteStatus: Codable {
  case favorited
  case unfavorited
}

struct SeasonItem: Identifiable {
  enum Kind {
    case episode(status: Status)
    case special(status: Status)
    case separator
  }

  var id: Int { index }
  let index: Int
  let kind: Kind
}

struct Season: Identifiable {
  let id: Int
  let items: [SeasonItem]
}

struct Show: Identifiable {
  let id: Int
  let title: String
  let tvmazeId: String
  let favorite: FavoriteStatus
  let location: String
  let episodeLength: String
  let seasons: [Season]

  struct SeenThru: Codable {
    let season: Int
    let episodesWatched: Int
  }
}

extension Show: Codable {
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

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.title = try container.decode(String.self, forKey: .title)
    self.tvmazeId = try container.decode(String.self, forKey: .tvmazeId)
    self.location = try container.decode(String.self, forKey: .location)
    self.episodeLength = try container.decode(String.self, forKey: .length)

    let boolFavorite = try container.decode(Bool.self, forKey: .favorite)
    self.favorite = boolFavorite ? .favorited : .unfavorited

    let seasonDescriptors = try container.decode([String].self, forKey: .seasonMaps)
    let seenThru = try container.decode(SeenThru.self, forKey: .seenThru)

    func watchedStatus(season: Int, episodeNum: Int, seenThru: SeenThru) -> Status {
      if season < seenThru.season {
        return .watched
      } else if season == seenThru.season && episodeNum <= seenThru.episodesWatched {
        return .watched
      } else {
        return .unwatched
      }
    }

    self.seasons = seasonDescriptors.enumerated().map { (idx, descriptor) -> Season in
      let seasonNum = idx + 1
      var episodeCounter = 1
      let items = descriptor.enumerated().map { (itemIdx, charCode) -> SeasonItem? in
        switch charCode {
          case ".", "S":
            let status = watchedStatus(season: seasonNum, episodeNum: episodeCounter, seenThru: seenThru)
            episodeCounter += 1
            let kind: SeasonItem.Kind = charCode == "S" ? .special(status: status) : .episode(status: status)
            return SeasonItem(index: itemIdx, kind: kind)
          case "+": return SeasonItem(index: itemIdx, kind: .separator)
          default: return nil
        }
      }.compactMap({ $0 })
      return Season(id: idx + 1, items: items)
    }
  }
  
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

    var lastWatchedSeason = 1, lastWatchedEpisodeNum = 0, episodeCounter = 0
    for (seasonIndex, season) in seasons.enumerated() {
      episodeCounter = 0
      for item in season.items {
        switch item.kind {
          case let .episode(status), let .special(status):
            episodeCounter += 1
            if status == .watched {
              lastWatchedSeason = seasonIndex + 1
              lastWatchedEpisodeNum = episodeCounter
            }
          default:
            break
        }
      }
    }
    let seenThru = SeenThru(season: lastWatchedSeason, episodesWatched: lastWatchedEpisodeNum)
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
