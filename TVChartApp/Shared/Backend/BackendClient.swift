import Foundation

private let reqTimeoutSecs = 10.0

struct ApiStatusUpdate: Encodable {
  let watched: [ApiEpisodeDescriptor]?
  let unwatched: [ApiEpisodeDescriptor]?
}

struct ApiEpisodeDescriptor: Encodable {
  let seasonIndex: Int
  let episodeIndex: Int

  init(from episodeDescriptor: EpisodeDescriptor) {
    self.seasonIndex = episodeDescriptor.season - 1
    self.episodeIndex = episodeDescriptor.episodeIndex
  }
}

enum BackendError: DisplayableError {
  case noReachableServers

  var displayDescription: String {
    switch self {
      case .noReachableServers:
        "No servers were reachable"
    }
  }

  var displayDetails: String? { nil }
}

private enum InternalBackendError: Error {
  case individualHostFailed(baseURL: URL, underlying: Error)
}

private enum URLPaths {
  static func allShows() -> String {
    return "shows"
  }

  static func show(showId: String) -> String {
    return "shows/\(showId)"
  }

  static func showUpdatingEpisodeStatus(showId: String) -> String {
    return "shows/\(showId)/update-status"
  }
}

// BackendClient is configured with one or more host URLs. For the initial request,
// it will try all hosts simultaneously; the first one that succeeds "wins" and
// only that host will be used from then on.
//
// This is a hack to support running the server on a port-forwarded local machine.
// Xfinity's router doesn't provide NAT loopback, so the external IP can only be
// used from outside the home network; at home, the internal IP has to be used.
class BackendClient {
  private let hostList: HostList
  private let urlSession: URLSession

  init(baseURLs: [URL]) {
    self.hostList = HostList(candidateBaseURLs: baseURLs)
    
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = reqTimeoutSecs
    self.urlSession = URLSession(configuration: config)
  }

  // Makes a backend request. If multiple hosts are configured, tries them all the first time
  // and continues to use whichever host responds successfully first for subsequent requests.
  // If no hosts succeed, tries all hosts again on the next request. If the previously selected
  // host no longer works (perhaps because the environment has changed, e.g. the user was on the
  // local network and is now remote), automatically retries all hosts again.
  func request(_ relativeURLString: String, httpMethod: String = "GET", body: Data? = nil) async throws -> (Data, URLResponse) {
    if await hostList.baseURLs.count == 0 {
      // previous request failed; retry all hosts in case the environment has changed
      await hostList.reset()
    }

    while true {
      if await hostList.baseURLs.count == 1 {
        do {
          return try await singleHostRequest(relativeURLString, httpMethod: httpMethod, body: body)
        } catch {
          if hostList.candidateBaseURLs.count == 1 {
            throw error
          } else {
            await hostList.reset()
            // fall through to retry
          }
        }
      } else {
        return try await multiHostRequest(relativeURLString, httpMethod: httpMethod, body: body)
      }
    }
  }

  private func makeURLRequest(relativeURLString: String, baseURL: URL, httpMethod: String, body: Data?) -> URLRequest {
    var req = URLRequest(url: URL(string: relativeURLString, relativeTo: baseURL)!)
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpMethod = httpMethod
    if let body {
      req.httpBody = body
    }
    return req
  }

  // Submit request to only a single host
  private func singleHostRequest(_ relativeURLString: String, httpMethod: String, body: Data?) async throws
    -> (Data, URLResponse)
  {
    let baseURL = await hostList.baseURLs.first!
    let req = makeURLRequest(relativeURLString: relativeURLString, baseURL: baseURL, httpMethod: httpMethod, body: body)
    do {
      return try await self.urlSession.data(for: req)
    } catch {
      throw BackendError.noReachableServers
    }
  }

  // Try all configured hosts; whichever succeeds first is the one we'll use going forward
  private func multiHostRequest(_ relativeURLString: String, httpMethod: String, body: Data?) async throws
    -> (Data, URLResponse) 
  {
    try await withThrowingTaskGroup(of: (URL, (Data, URLResponse)).self, returning: (Data, URLResponse).self) { group in
      await populateTaskGroup(&group, relativeURLString: relativeURLString, httpMethod: httpMethod, body: body)

      while !group.isEmpty {
        do {
          if let (baseURL, (data, rsp)) = try await group.next() {
            group.cancelAll()
            await hostList.anointWinner(baseURL)
            return (data, rsp)
          }
        } catch let InternalBackendError.individualHostFailed(baseURL, underlying) {
          await hostList.removeLoser(baseURL)
        }
      }
      throw BackendError.noReachableServers
    }
  }

  private func populateTaskGroup(
    _ group: inout ThrowingTaskGroup<(URL, (Data, URLResponse)), Error>,
    relativeURLString: String,
    httpMethod: String,
    body: Data?
  ) async
  {
    for baseURL in await hostList.baseURLs {
      let req = makeURLRequest(relativeURLString: relativeURLString, baseURL: baseURL, httpMethod: httpMethod, body: body)

      group.addTask { [req] in
        do {
          return (baseURL, try await self.urlSession.data(for: req))
        } catch {
          throw InternalBackendError.individualHostFailed(baseURL: baseURL, underlying: error)
        }
      }
    }
  }

  func fetchAllShows() async throws -> [Show] {
    do {
      let (data, rsp) = try await request(URLPaths.allShows())
      try rsp.validate(data)
      return try await MainActor.run {
        try JSONDecoder().decode([ShowDTO].self, from: data).map { $0.toShow() }
      }
    } catch {
      throw ConnectionError.loadShowsFailed(cause: error)
    }
  }

  func updateEpisodeStatuses(showId: Int, watched: [ApiEpisodeDescriptor], unwatched: [ApiEpisodeDescriptor]) async throws {
    let body = ApiStatusUpdate(watched: watched, unwatched: unwatched)
    do {
      let (data, rsp) = try await request(
        URLPaths.showUpdatingEpisodeStatus(showId: String(showId)),
        httpMethod: "POST",
        body: JSONEncoder().encode(body)
      )
      try rsp.validate(data)
    } catch {
      throw ConnectionError.updateStatusFailed(cause: error)
    }
  }
}

// Keeps track of configured hosts and their connection status.
private actor HostList {
  let candidateBaseURLs: [URL]
  var baseURLs: [URL]

  init(candidateBaseURLs: [URL]) {
    self.candidateBaseURLs = candidateBaseURLs
    self.baseURLs = candidateBaseURLs
  }

  func anointWinner(_ url: URL) {
    guard baseURLs.contains(url) else { return }
    baseURLs.removeAll { $0 != url }
  }

  func removeLoser(_ url: URL) {
    baseURLs.removeAll { $0 == url }
  }

  // Resets to the original list of available servers; to be used when
  // all hosts fail a request. That could happen because of a network blip, or
  // because the network context has changed.
  func reset() {
    self.baseURLs = candidateBaseURLs
  }
}

