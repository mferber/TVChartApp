import Foundation
import SwiftUI
import Combine

protocol BackendProtocol {
  func fetch() async throws -> [Show]
  func updateEpisodeStatus(
    show: Show,
    watched: [EpisodeDescriptor]?,
    unwatched: [EpisodeDescriptor]?
  ) async throws -> Show
}

class Backend: BackendProtocol {
  private var client: BackendClient

  init(baseURL: URL) {
    client = BackendClient(baseURL: baseURL)
  }

  func fetch() async throws -> [Show] {
    return try await client.fetchAllShows().sortedByTitle
  }

  func updateEpisodeStatus(
    show: Show,
    watched: [EpisodeDescriptor]?, unwatched: [EpisodeDescriptor]?
  ) async throws -> Show {
    return try await client.updateEpisodeStatus(show: show, watched: watched, unwatched: unwatched)
  }
}

class BackendStub: BackendProtocol {
  var fetchResult: [Show] = []

  func fetch() async throws -> [Show] { return fetchResult }

  func updateEpisodeStatus(
    show: Show,
    watched: [EpisodeDescriptor]?,
    unwatched: [EpisodeDescriptor]?
  ) async throws -> Show {
    return show
  }
}
