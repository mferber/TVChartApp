import Foundation

enum Status: Codable {
  case unwatched
  case watched
}

enum FavoriteStatus: Codable {
  case favorited
  case unfavorited
}

enum SeasonItem: Codable {
  case episode(status: Status)
  case special(status: Status)
  case separator
}

struct Season: Codable {
  let items: [SeasonItem]
}

struct Show: Decodable {
  let id: Int
  let title: String
  let tvmazeId: String
  let favorite: FavoriteStatus
  let location: String
  let episodeLength: String
  let seasons: [Season]

  struct SeenThru: Decodable {
    let season: Int
    let episodesWatched: Int
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
      let items = descriptor.map { charCode -> SeasonItem? in
        switch charCode {
          case ".", "S":
            let status = watchedStatus(season: seasonNum, episodeNum: episodeCounter, seenThru: seenThru)
            episodeCounter += 1
            return charCode == "S" ? .special(status: status) : .episode(status: status)
          case "+": return .separator
          default: return nil
        }
      }.compactMap({ $0 })
      return Season(items: items)
    }
  }
}
