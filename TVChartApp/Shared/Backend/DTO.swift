import Foundation

struct ShowDTO: Codable {
  let id: Int
  let title: String
  let tvmazeId: String
  let favorite: Bool
  let location: String
  let length: String
  let seasonMaps: [String]
  let watchedEpisodeMaps: [String]

  static func from(_ show: Show) -> ShowDTO {
    let seasonMaps = show.seasons.map { season in
      season.items.map {
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

    let watchedEpisodeMaps = show.seasons.map { season in
      season.items.compactMap { $0 as? Episode }.map { episode in
        episode.isWatched ? "x" : "."
      }.joined(separator: "")
    }

    return ShowDTO(
      id: show.id,
      title: show.title,
      tvmazeId: show.tvmazeId,
      favorite: show.favorite == .favorited, 
      location: show.location,
      length: show.episodeLength,
      seasonMaps: seasonMaps,
      watchedEpisodeMaps: watchedEpisodeMaps
    )
  }

  func toShow() -> Show {
    let favorite: FavoriteStatus = self.favorite ? .favorited : .unfavorited

    let seasons = seasonMaps.enumerated().map { (seasonIdx, seasonMap) in
      Season(number: seasonIdx + 1, items: parseSeasonItems(seasonMap))
    }

    for (seasonIdx, season) in seasons.enumerated() {
      updateEpisodeWatchedStatus(
        season,
        seasonIndex: seasonIdx,
        watchedEpisodeMap: watchedEpisodeMaps[safe: seasonIdx] ?? ""
      )
    }

    let show = Show(id: self.id, title: self.title, tvmazeId: self.tvmazeId, favorite: favorite, location: self.location, episodeLength: self.length, seasons: seasons)

    // back links
    for season in seasons {
      for item in season.items {
        item.season = season
      }
      season.show = show
    }

    return show
  }

  // decode a string of characters, each representing one season item
  // . = numbered episode
  // S = special episode
  // + = separator
  private func parseSeasonItems(_ seasonMap: String) -> [SeasonItem] {
    var episodeIndex = 0, nextEpisodeNumber = 1

    return seasonMap.enumerated().map { (itemIdx, charCode) -> SeasonItem? in
      switch charCode {

        case ".":
          let episode = NumberedEpisode(
            index: itemIdx,
            episodeIndex: episodeIndex,
            episodeNumber: nextEpisodeNumber,
            isWatched: false // watchedEpisodeMaps[safe: seasonIdx]?[safe: episodeIndex] ?? false
          )
          nextEpisodeNumber += 1
          episodeIndex += 1
          return episode

        case "S":
          let episode = SpecialEpisode(
            index: itemIdx,
            episodeIndex: episodeIndex,
            isWatched: false // watchedEpisodeMaps[safe: seasonIdx]?[safe: episodeIndex] ?? false
          )
          episodeIndex += 1
          return episode

        case "+":
          return Separator(index: itemIdx)

        default:
          return nil
      }
    }.compactMap({ $0 })
  }

  // decode a string of characters, each representing one season item -- SPECIALS ARE OMITTED
  // . = unwatched episode
  // x = watched episode
  private func updateEpisodeWatchedStatus(_ season: Season, seasonIndex: Int, watchedEpisodeMap: String) {
    let episodes = season.items.compactMap({ $0 as? Episode })
    for (index, episodeIndicator) in watchedEpisodeMap.enumerated() {
      if episodeIndicator == "x" {
        episodes[safe: index]?.isWatched = true
      }
    }
  }
}
