import Foundation

class BackendClient {
  struct URLs {
    let baseURL: URL

    private func create(_ path: String) -> URL {
      return URL(string: path, relativeTo: baseURL)!
    }

    func allShows() -> URL {
      return create("/shows")
    }

    func show(showId: String) -> URL {
      return create("/shows/\(showId)")
    }
  }

  let urls: URLs

  init(baseURL: URL) {
    self.urls = URLs(baseURL: baseURL)
  }

  func fetchAllShows() async throws -> [Show] {
    var req = URLRequest(url: urls.allShows())
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let (data, rsp) = try await URLSession.shared.data(for: req)
    try rsp.validate(data)

    return try JSONDecoder().decode([Show].self, from: data)
  }

  func patchShowSeenThru(show: Show) async throws -> Show {
    var req = URLRequest(url: urls.show(showId: String(show.id)))
    req.httpMethod = "PATCH"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONEncoder().encode(SeenThruPartial(seenThru: show.seenThru))

    let (data, rsp) = try await URLSession.shared.data(for: req)
    try rsp.validate(data)

    return try JSONDecoder().decode(Show.self, from: data)
  }
}
