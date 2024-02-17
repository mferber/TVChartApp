import Foundation
import Nimble
import Quick

@testable import TVChartApp

final class ModelsSpec: QuickSpec {
  override class func spec() {
    describe("Serialized show info") {
      it("deserializes correctly") {
        let json = """
        {
          "id": 1,
          "title": "For All Mankind",
          "favorite": true,
          "tvmazeId": "41414",
          "location": "Apple TV+",
          "length": "1 hour",
          "seasonMaps": ["....", "S.+.."],
          "seenThru": { "season": 2, "episodesWatched": 3 }
        }
        """.data(using: .utf8)!

        let decoded: Show = try! JSONDecoder().decode(Show.self, from: json)
        expect(decoded.id).to(equal(1))
        expect(decoded.title).to(equal("For All Mankind"))
        expect(decoded.favorite).to(equal(.favorited))
        expect(decoded.tvmazeId).to(equal("41414"))
        expect(decoded.location).to(equal("Apple TV+"))
        expect(decoded.episodeLength).to(equal("1 hour"))
  
        let seasons = decoded.seasons
        expect(seasons).to(haveCount(2))

        expect(seasons[0].items).to(haveCount(4))
        for item in seasons[0].items {
          if case let .episode(status) = item {
            expect(status).to(equal(.watched))
          } else {
            fail("Expected .episode, got \(item)")
          }
        }

        expect(seasons[1].items).to(haveCount(5))
        for (index, item) in seasons[1].items.enumerated() {
          switch index {
            case 0:
              if case let .special(status) = item {
                expect(status).to(equal(.watched))
              } else {
                fail("Expected .special, got \(item)")
              }
            case 1, 3:
              if case let .episode(status) = item {
                expect(status).to(equal(.watched))
              } else {
                fail("Expected .episode, got \(item)")
              }
            case 2:
              if case .separator = item {
              } else {
                fail("Expected .separator, got \(item)")
              }
            case 4:
              if case let .episode(status) = item {
                expect(status).to(equal(.unwatched))
              } else {
                fail("Expected .episode, got \(item)")
              }
            default:
              fail("Unexpected index")
          }
        }
      }
    }
  }
}
