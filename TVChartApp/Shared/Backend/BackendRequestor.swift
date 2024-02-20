import Foundation

class BackendRequestor {
  private let serverUrl: URL

  init(serverUrl: URL) {
    self.serverUrl = serverUrl
  }

  func fetchListings() async throws -> [Show] {
    let (data, rsp) = try await URLSession.shared.data(from: serverUrl)
    try rsp.validate()
    return try JSONDecoder().decode([Show].self, from: data)
  }
}
