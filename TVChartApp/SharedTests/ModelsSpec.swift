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

      context("serialization") {
        it("handles a typical example") {
          let show = Show(
            id: 1,
            title: "Taskmaster",
            tvmazeId: "2955",
            favorite: .favorited,
            location: "YouTube",
            episodeLength: "1 hour",
            seasons: [
              Season(
                id: 1,
                items: [
                  .episode(status: .watched),
                  .episode(status: .watched),
                  .episode(status: .watched)
                ]
              ),
              Season(
                id: 2,
                items: [
                  .episode(status: .watched),
                  .special(status: .watched),
                  .separator,
                  .episode(status: .watched),
                  .special(status: .unwatched)
                ]
              )
            ]
          )
          let json = try! JSONEncoder().encode(show)

          let decoded = try! JSONSerialization.jsonObject(with: json) as! NSDictionary
          expect(decoded["id"] as? Int).to(equal(1))
          expect(decoded["title"] as? String).to(equal("Taskmaster"))
          expect(decoded["tvmazeId"] as? String).to(equal("2955"))
          expect(decoded["favorite"] as? Bool).to(beTrue())
          expect(decoded["location"] as? String).to(equal("YouTube"))
          expect(decoded["length"] as? String).to(equal("1 hour"))

          expect(decoded["seasonMaps"] as? [String]).to(equal(["...", ".S+.S"]))
          let seenThru = decoded["seenThru"] as! NSDictionary
          expect(seenThru["season"] as? Int).to(equal(2))
          expect(seenThru["episodesWatched"] as? Int).to(equal(3))
        }
      }

      it("handles an unstarted show") {
        let seasons: [Season] = [
          Season(
            id: 1,
            items: [
              .episode(status: .unwatched),
              .episode(status: .unwatched)
            ]),
          Season(
            id: 2,
            items: [
              .episode(status: .unwatched),
              .episode(status: .unwatched)
            ])
        ]
        let show = Show(id: 1, title: "", tvmazeId: "", favorite: .favorited, location: "", episodeLength: "",
                        seasons: seasons)
        let encoded = try! JSONEncoder().encode(show)

        let decoded = try! JSONSerialization.jsonObject(with: encoded) as! NSDictionary
        let seenThru = decoded["seenThru"] as! NSDictionary
        expect(seenThru["season"] as? Int).to(equal(1))
        expect(seenThru["episodesWatched"] as? Int).to(equal(0))
      }

      it("handles an unstarted new season") {
        let seasons: [Season] = [
          Season(
            id: 1,
            items: [
              .episode(status: .watched),
              .separator,
              .episode(status: .watched)
            ]),
          Season(
            id: 2,
            items: [
              .episode(status: .unwatched),
              .separator,
              .episode(status: .unwatched)
            ])
        ]
        let show = Show(id: 1, title: "", tvmazeId: "", favorite: .favorited, location: "", episodeLength: "",
                        seasons: seasons)
        let encoded = try! JSONEncoder().encode(show)

        let decoded = try! JSONSerialization.jsonObject(with: encoded) as! NSDictionary
        let seenThru = decoded["seenThru"] as! NSDictionary
        expect(seenThru["season"] as? Int).to(equal(1))
        expect(seenThru["episodesWatched"] as? Int).to(equal(2))
      }


      it("ignores gaps for purposes of computing the 'last watched' episode") {
        let seasons: [Season] = [
          Season(
            id: 1,
            items: [
              .episode(status: .watched),
              .separator,
              .episode(status: .watched)
            ]),
          Season(
            id: 2,
            items: [
              .episode(status: .unwatched),
              .separator,
              .episode(status: .watched)
            ])
        ]
        let show = Show(id: 1, title: "", tvmazeId: "", favorite: .favorited, location: "", episodeLength: "",
                        seasons: seasons)
        let encoded = try! JSONEncoder().encode(show)

        let decoded = try! JSONSerialization.jsonObject(with: encoded) as! NSDictionary
        let seenThru = decoded["seenThru"] as! NSDictionary
        expect(seenThru["season"] as? Int).to(equal(2))
        expect(seenThru["episodesWatched"] as? Int).to(equal(2))
      }
    }
  }
}
