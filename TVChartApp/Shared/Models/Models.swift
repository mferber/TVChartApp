import Foundation
import Observation

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

@Observable
class Episode: SeasonItem {
  // 0-based, episode counter (ignoring separators)
  let episodeIndex: Int
  var isWatched: Bool

  fileprivate init(index: Int, episodeIndex: Int, isWatched: Bool) {
    self.episodeIndex = episodeIndex
    self.isWatched = isWatched
    
    super.init(index: index)
  }

  var descriptor: EpisodeDescriptor {
    return EpisodeDescriptor(showId: season.show.id, season: season.number, episodeIndex: episodeIndex)
  }
}

class NumberedEpisode: Episode, CustomStringConvertible {
  let episodeNumber: Int  // official episode number; specials aren't numbered

  init(index: Int, episodeIndex: Int, episodeNumber: Int, isWatched: Bool) {
    self.episodeNumber = episodeNumber

    super.init(index: index, episodeIndex: episodeIndex, isWatched: isWatched)
  }

  var description: String {
    "NumberedEpisode { \(season.show.title), season \(season.number), index \(episodeIndex), number \(episodeNumber) }"
  }
}

class SpecialEpisode: Episode, CustomStringConvertible {
  override init(index: Int, episodeIndex: Int, isWatched: Bool) {
    super.init(index: index, episodeIndex: episodeIndex, isWatched: isWatched)
  }
  
  var description: String {
    "SpecialEpisode { \(season.show.title), season \(season.number), index \(episodeIndex) }"
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

  var isCompleted: Bool {
    return items.allSatisfy { ($0 as? Episode)?.isWatched ?? true }
  }

  init(number: Int, items: [SeasonItem]) {
    self.number = number
    self.items = items
  }
}

class Show: Identifiable {
  var id: Int
  var tvmazeId: String
  var title: String
  var favorite: FavoriteStatus
  var location: String
  var episodeLength: String
  var seasons: [Season]

  init(id: Int, title: String, tvmazeId: String, favorite: FavoriteStatus, location: String,
       episodeLength: String, seasons: [Season]) {
    self.id = id
    self.title = title
    self.tvmazeId = tvmazeId
    self.favorite = favorite
    self.location = location
    self.episodeLength = episodeLength
    self.seasons = seasons

    hookUpBackLinks()
  }

  var isFavorite: Bool {
    if case .favorited = favorite {
      return true
    }
    return false
  }

  private func hookUpBackLinks() {
    for season in self.seasons {
      for item in season.items {
        item.season = season
      }
      season.show = self
    }
  }

  func markWatchedUpTo(targetEpisode: Episode) -> [EpisodeDescriptor] {
    var updatedEpisodes: [EpisodeDescriptor] = []
  outer:
    for season in self.seasons {
      for episode in season.items.compactMap({ $0 as? Episode }) {
        if (season.number < targetEpisode.season.number ||
            season.number == targetEpisode.season.number && episode.episodeIndex <= targetEpisode.episodeIndex) {
          if !episode.isWatched {
            episode.isWatched = true
            updatedEpisodes.append(EpisodeDescriptor(
              showId: season.show.id,
              season: season.number,
              episodeIndex: episode.episodeIndex)
            )
          }
        } else {
          break outer
        }
      }
    }
    return updatedEpisodes
  }
}

extension [Show] {
  var favoritesOnly: [Show] {
    return self.filter { $0.isFavorite }
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

struct EpisodeDescriptor: Equatable {
  let showId: Int
  let season: Int
  let episodeIndex: Int

  func matches(_ episode: Episode) -> Bool {
    return showId == episode.season.show.id && season == episode.season.number && episodeIndex == episode.episodeIndex
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
