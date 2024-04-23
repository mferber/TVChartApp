import Foundation

struct ApiStatusUpdate: Encodable {
  let watched: [ApiEpisodeDescriptor]?
  let unwatched: [ApiEpisodeDescriptor]?
}

struct ApiEpisodeDescriptor: Encodable {
  let seasonIndex: Int
  let episodeIndex: Int
}

class BackendClient {
  struct URLs {
    let baseURL: URL

    private func url(_ path: String) -> URL {
      return URL(string: path, relativeTo: baseURL)!
    }

    func allShows() -> URL {
      return url("shows")
    }

    func show(showId: String) -> URL {
      return url("shows/\(showId)")
    }

    func showUpdatingEpisodeStatus(showId: String) -> URL {
      return url("shows/\(showId)/update-status")
    }
  }

  let urls: URLs

  init(baseURL: URL) {
    self.urls = URLs(baseURL: baseURL)
  }

  func fetchAllShows() async throws -> [Show] {
    var req = URLRequest(url: urls.allShows())
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

    do {
      let (data, rsp) = try await URLSession.shared.data(for: req)
      try rsp.validate(data)
      return try await MainActor.run {
        try JSONDecoder().decode([ShowDTO].self, from: data).map { $0.toShow() }
      }
    } catch {
      throw ConnectionError.loadShowsFailed(cause: error)
    }
  }

  func updateEpisodeStatus(show: Show, watched: [EpisodeDescriptor]?, unwatched: [EpisodeDescriptor]?) async throws -> Show {
    var req = URLRequest(url: urls.showUpdatingEpisodeStatus(showId: String(show.id)))
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = ApiStatusUpdate(
      watched: watched?.map { ApiEpisodeDescriptor(seasonIndex: $0.season - 1, episodeIndex: $0.episodeIndex) },
      unwatched: unwatched?.map { ApiEpisodeDescriptor(seasonIndex: $0.season - 1, episodeIndex: $0.episodeIndex) }
    )

    do {
      req.httpBody = try JSONEncoder().encode(body)
      let (data, rsp) = try await URLSession.shared.data(for: req)
      try rsp.validate(data)
      return try await MainActor.run {
        try JSONDecoder().decode(ShowDTO.self, from: data).toShow()
      }
    } catch {
      throw ConnectionError.updateStatusFailed(cause: error)
    }
  }
}
