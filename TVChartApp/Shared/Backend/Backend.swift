import Foundation
import SwiftUI
import Combine

protocol BackendProtocol {
  func fetch() async throws -> [Show]
  func updateEpisodeStatus(episode: Episode, watched: Bool) async throws
  func updateEpisodeStatuses(
    watched: [EpisodeDescriptor],
    unwatched: [EpisodeDescriptor]
  ) async throws
}

class Backend: BackendProtocol {
  private var client: BackendClient

  init(baseURLs: [URL]) {
    client = BackendClient(baseURLs: baseURLs)
  }

  func fetch() async throws -> [Show] {
    return try await client.fetchAllShows().sortedByTitle
  }

  func updateEpisodeStatus(episode: Episode, watched: Bool) async throws {
    let showId = await episode.season.show.id
    let descriptor = ApiEpisodeDescriptor(from: await episode.descriptor)
    let watchedEpisodes = watched ? [descriptor] : []
    let unwatchedEpisodes = watched ? [] : [descriptor]
    try await client.updateEpisodeStatuses(showId: showId, watched: watchedEpisodes, unwatched: unwatchedEpisodes)
  }

  func updateEpisodeStatuses(watched: [EpisodeDescriptor], unwatched: [EpisodeDescriptor]) async throws {
    let watchedGroups = Dictionary(grouping: watched, by: \.showId)
    let unwatchedGroups = Dictionary(grouping: unwatched, by: \.showId)
    let showIds = Set(watchedGroups.keys).union(Set(unwatchedGroups.keys))

    for showId in showIds {
      let showWatched = (watchedGroups[showId] ?? []).map { ApiEpisodeDescriptor(from: $0) }
      let showUnwatched = (unwatchedGroups[showId] ?? []).map { ApiEpisodeDescriptor(from: $0) }
      try await client.updateEpisodeStatuses(showId: showId, watched: showWatched, unwatched: showUnwatched)
    }
  }
}

class BackendStub: BackendProtocol {
  var fetchResult: [Show] = []
  func fetch() async throws -> [Show] { return fetchResult }
  func updateEpisodeStatus(episode: Episode, watched: Bool) async throws { }
  func updateEpisodeStatuses(watched: [EpisodeDescriptor], unwatched: [EpisodeDescriptor]) async throws { }
}
