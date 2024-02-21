import XCTest
import Nimble
@testable import TVChartApp

final class ModelsTests: XCTestCase {

  func testSerializedShowInfoDeserializesCorrectly() {
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

    let show: Show = try! JSONDecoder().decode(Show.self, from: json)
    expect(show.title).to(equal("For All Mankind"))
    expect(show.favorite).to(equal(.favorited))
    expect(show.tvmazeId).to(equal("41414"))
    expect(show.location).to(equal("Apple TV+"))
    expect(show.episodeLength).to(equal("1 hour"))

    let seasons = show.seasons
    expect(seasons).to(haveCount(2))

    expect(seasons[0].show).to(be(show))
    expect(seasons[0].number).to(equal(1))
    expect(seasons[0].items).to(haveCount(4))
    for item in seasons[0].items {
      expect(item.season).to(be(seasons[0]))

      if case let .episode(_, status) = item.kind {
        expect(status).to(equal(.watched))
      } else {
        fail("Expected .episode, got \(item)")
      }
    }

    expect(seasons[1].number).to(equal(2))
    expect(seasons[1].items).to(haveCount(5))
    for (index, item) in seasons[1].items.enumerated() {
      expect(item.id).to(equal(index))
      expect(item.season).to(be(seasons[1]))

      switch index {
        case 0:
          if case let .special(status) = item.kind {
            expect(status).to(equal(.watched))
          } else {
            fail("Expected .special, got \(item)")
          }
        case 1, 3:
          if case let .episode(_, status) = item.kind {
            expect(status).to(equal(.watched))
          } else {
            fail("Expected .episode, got \(item)")
          }
        case 2:
          if case .separator = item.kind {
          } else {
            fail("Expected .separator, got \(item)")
          }
        case 4:
          if case let .episode(_, status) = item.kind {
            expect(status).to(equal(.unwatched))
          } else {
            fail("Expected .episode, got \(item)")
          }
        default:
          fail("Unexpected index")
      }
    }
  }

  func testTypicalShowInfoSerializesCorrectly() {
    let show = Show(
      title: "Taskmaster",
      tvmazeId: "2955",
      favorite: .favorited,
      location: "YouTube",
      episodeLength: "1 hour",
      seasons: [
        Season(
          number: 1,
          items: [
            SeasonItem(index: 0, kind: .episode(number: 1, status: .watched)),
            SeasonItem(index: 1, kind: .episode(number: 2, status: .watched)),
            SeasonItem(index: 2, kind: .episode(number: 3, status: .watched))
          ]
        ),
        Season(
          number: 2,
          items: [
            SeasonItem(index: 0, kind: .episode(number: 1, status: .watched)),
            SeasonItem(index: 1, kind: .special(status: .watched)),
            SeasonItem(index: 2, kind: .separator),
            SeasonItem(index: 3, kind: .episode(number: 2, status: .watched)),
            SeasonItem(index: 4, kind: .special(status: .unwatched))
          ]
        )
      ]
    )
    let json = try! JSONEncoder().encode(show)

    let decoded = try! JSONSerialization.jsonObject(with: json) as! NSDictionary
    expect(decoded["id"] as? String).to(equal("2955"))
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

  func testUnstartedShowSerializesCorrectly() {
    let seasons: [Season] = [
      Season(
        number: 1,
        items: [
          SeasonItem(index: 0, kind: .episode(number: 1, status: .unwatched)),
          SeasonItem(index: 1, kind: .episode(number: 2, status: .unwatched))
        ]),
      Season(
        number: 2,
        items: [
          SeasonItem(index: 0, kind: .episode(number: 1, status: .unwatched)),
          SeasonItem(index: 1, kind: .episode(number: 2, status: .unwatched))
        ])
    ]
    let show = Show(title: "", tvmazeId: "", favorite: .favorited, location: "", episodeLength: "",
                    seasons: seasons)
    let encoded = try! JSONEncoder().encode(show)

    let decoded = try! JSONSerialization.jsonObject(with: encoded) as! NSDictionary
    let seenThru = decoded["seenThru"] as! NSDictionary
    expect(seenThru["season"] as? Int).to(equal(1))
    expect(seenThru["episodesWatched"] as? Int).to(equal(0))
  }

  func testShowWithUnstartedSeasonSerializesCorrectly() {
    let seasons: [Season] = [
      Season(
        number: 1,
        items: [
          SeasonItem(index: 0, kind: .episode(number: 1, status: .watched)),
          SeasonItem(index: 1, kind: .separator),
          SeasonItem(index: 2, kind: .episode(number: 2, status: .watched))
        ]),
      Season(
        number: 2,
        items: [
          SeasonItem(index: 0, kind: .episode(number: 1, status: .unwatched)),
          SeasonItem(index: 1, kind: .separator),
          SeasonItem(index: 2, kind: .episode(number: 2, status: .unwatched)),
        ])
    ]
    let show = Show(title: "", tvmazeId: "", favorite: .favorited, location: "", episodeLength: "",
                    seasons: seasons)
    let encoded = try! JSONEncoder().encode(show)

    let decoded = try! JSONSerialization.jsonObject(with: encoded) as! NSDictionary
    let seenThru = decoded["seenThru"] as! NSDictionary
    expect(seenThru["season"] as? Int).to(equal(1))
    expect(seenThru["episodesWatched"] as? Int).to(equal(2))
  }

  // this is a stopgap while the server-side data model still tracks only "last watched
  // episode" -- the intent is to convert to tracking each episode's status individually
  func testGapsAreIgnoredWhenDeterminingLastWatchedEpisode() {
    let seasons: [Season] = [
      Season(
        number: 1,
        items: [
          SeasonItem(index: 0, kind: .episode(number: 1, status: .watched)),
          SeasonItem(index: 1, kind: .separator),
          SeasonItem(index: 2, kind: .episode(number: 2, status: .watched))
        ]
      ),
      Season(
        number: 2,
        items: [
          SeasonItem(index: 0, kind: .episode(number: 1, status: .unwatched)),
          SeasonItem(index: 1, kind: .separator),
          SeasonItem(index: 2, kind: .episode(number: 2, status: .watched))
        ]
      )
    ]
    let show = Show(title: "", tvmazeId: "", favorite: .favorited, location: "", episodeLength: "",
                    seasons: seasons)
    let encoded = try! JSONEncoder().encode(show)

    let decoded = try! JSONSerialization.jsonObject(with: encoded) as! NSDictionary
    let seenThru = decoded["seenThru"] as! NSDictionary
    expect(seenThru["season"] as? Int).to(equal(2))
    expect(seenThru["episodesWatched"] as? Int).to(equal(2))
  }

  func testTVmazeMetadataDeserializesNormalEpisodeCorrectly() {
    let json = """
      [
        {
          "id": 40138,
          "url": "https://www.tvmaze.com/episodes/40138/buffy-the-vampire-slayer-6x07-once-more-with-feeling",
          "name": "Once More, with Feeling",
          "season": 6,
          "number": 7,
          "type": "regular",
          "airdate": "2001-11-06",
          "airtime": "20:00",
          "airstamp": "2001-11-07T01:00:00+00:00",
          "runtime": 60,
          "rating": {
            "average": 8.4
          },
          "image": {
            "medium": "https://static.tvmaze.com/uploads/images/medium_landscape/14/37391.jpg",
            "original": "https://static.tvmaze.com/uploads/images/original_untouched/14/37391.jpg"
          },
          "summary": "<p>Sunnydale is alive with the sound of music as a mysterious force causes everyone in town to burst into full musical numbers, revealing their innermost secrets as they do. But some townsfolk are dancing so much that they simply burst into flames, and it becomes clear that maybe living in a musical isn't so great after all.</p>",
          "_links": {
            "self": {
              "href": "https://api.tvmaze.com/episodes/40138"
            },
            "show": {
              "href": "https://api.tvmaze.com/shows/427"
            }
          }
        }
      ]
      """.data(using: .utf8)!

    let seasonMetadata = try! JSONDecoder()
      .decode([EpisodeMetadata.DTO].self, from: json)
      .map { $0.toDomain() }
    expect(seasonMetadata).to(haveCount(1))
    let episode = seasonMetadata[0]
    expect(episode.title).to(equal("Once More, with Feeling"))
    expect(episode.season).to(equal(6))
    expect(episode.episode).to(equal(7))
    expect(episode.length).to(equal("60 min."))
    expect(episode.synopsis).to(contain("Sunnydale is alive"))

    // html tags should be gone
    expect(episode.synopsis).notTo(match("<.*>"))
  }

  func testTVmazeMetadataDeserializesSpecialEpisodeCorrectly() {
    let json =
    """
    {
      "id": 13977,
      "url": "https://www.tvmaze.com/episodes/13977/doctor-who-s05-special-a-christmas-carol",
      "name": "A Christmas Carol",
      "season": 5,
      "number": null,
      "type": "significant_special",
      "airdate": "2010-12-25",
      "airtime": "19:35",
      "airstamp": "2010-12-25T19:35:00+00:00",
      "runtime": 63,
      "rating": {
        "average": 6.9
      },
      "image": {
        "medium": "https://static.tvmaze.com/uploads/images/medium_landscape/141/352739.jpg",
        "original": "https://static.tvmaze.com/uploads/images/original_untouched/141/352739.jpg"
      },
      "summary": "<p>Amy and Rory are trapped on a crashing space liner, and the only way The Doctor can rescue them is to save the soul of a lonely old miser. But is Kazran Sardick, the richest man in Sardicktown, beyond redemption? And what is lurking in the fogs of Christmas Eve?</p>",
      "_links": {
        "self": {
          "href": "https://api.tvmaze.com/episodes/13977"
        },
        "show": {
          "href": "https://api.tvmaze.com/shows/210"
        }
      }
    }
    """.data(using: .utf8)!

    let episode = try! JSONDecoder().decode(EpisodeMetadata.DTO.self, from: json).toDomain()
    expect(episode.season).to(equal(5))
    expect(episode.episode).to(beNil())
  }
}
