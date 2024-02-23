import Foundation
import Combine

struct MetadataClient {

  struct URLs {
    static let metadataProviderApiBaseURL = URL(string: "https://api.tvmaze.com/")!

    private func create(_ path: String) -> URL {
      return URL(string: path, relativeTo: Self.metadataProviderApiBaseURL)!
    }

    func show(showId: String) -> URL {
      return create("shows/\(showId.urlPathEncoded)/episodes?specials=1")
    }
  }

  let urls = URLs()

  func fetchShowMetadata(show: Show) async throws -> [EpisodeMetadata] {
    let url = urls.show(showId: show.tvmazeId)

    let (data, rsp) = try! await URLSession.shared.data(from: url)
    try rsp.validate(data)
    
    return try JSONDecoder().decode([EpisodeMetadata.DTO].self, from: data).map { $0.toDomain() }
  }
} 

