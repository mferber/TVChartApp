import XCTest
import Nimble
@testable import TVChartApp

final class ModelsTests: XCTestCase {

  @MainActor
  func test_Show_deserializesCorrectly() {
    let json = """
      {
        "id": 1,
        "title": "For All Mankind",
        "favorite": true,
        "tvmazeId": "41414",
        "location": "Apple TV+",
        "length": "1 hour",
        "seasonMaps": ["....", "S.+.."],
        "watchedEpisodeMaps": ["xx..", "...x" ]
      }
      """.data(using: .utf8)!

      let show: Show = try! JSONDecoder().decode(ShowDTO.self, from: json).toShow()
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
        expect(item).to(beAnInstanceOf(NumberedEpisode.self))
      }
      expect((seasons[0].items[0] as! Episode).isWatched).to(beTrue())
      expect((seasons[0].items[1] as! Episode).isWatched).to(beTrue())
      expect((seasons[0].items[2] as! Episode).isWatched).to(beFalse())
      expect((seasons[0].items[3] as! Episode).isWatched).to(beFalse())

      expect(seasons[1].number).to(equal(2))
      expect(seasons[1].items).to(haveCount(5))
      for (index, item) in seasons[1].items.enumerated() {
        expect(item.id).to(equal(index))
        expect(item.season).to(be(seasons[1]))

        switch index {
          case 0:
            expect(item).to(beAnInstanceOf(SpecialEpisode.self))
          case 1, 3, 4:
            expect(item).to(beAnInstanceOf(NumberedEpisode.self))
          case 2:
            expect(item).to(beAnInstanceOf(Separator.self))
          default:
            fail("Unexpected index")
        }
      }
      expect((seasons[1].items[0] as! Episode).isWatched).to(beFalse())
      expect((seasons[1].items[1] as! Episode).isWatched).to(beFalse())
      expect((seasons[1].items[3] as! Episode).isWatched).to(beFalse())
      expect((seasons[1].items[4] as! Episode).isWatched).to(beTrue())
  }

  @MainActor
  func test_Show_typicalShowSerializesCorrectly() {
    let show = Show(
      id: 0,
      title: "Taskmaster",
      tvmazeId: "2955",
      favorite: .favorited,
      location: "YouTube",
      episodeLength: "1 hour",
      seasons: [
        Season(
          number: 1,
          items: [
            NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: false),
            NumberedEpisode(index: 1, episodeIndex: 1, episodeNumber: 2, isWatched: true),
            NumberedEpisode(index: 2, episodeIndex: 2, episodeNumber: 3, isWatched: true)
          ]
        ),
        Season(
          number: 2,
          items: [
            NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: true),
            SpecialEpisode(index: 1, episodeIndex: 1, isWatched: true),
            Separator(index: 2),
            NumberedEpisode(index: 3, episodeIndex: 2, episodeNumber: 1, isWatched: true),
            SpecialEpisode(index: 0, episodeIndex: 0, isWatched: false)
          ]
        )
      ]
    )
    let json = try! JSONEncoder().encode(ShowDTO.from(show))

    let decoded = try! JSONSerialization.jsonObject(with: json) as! NSDictionary
    expect(decoded["id"] as? Int).to(equal(0))
    expect(decoded["title"] as? String).to(equal("Taskmaster"))
    expect(decoded["tvmazeId"] as? String).to(equal("2955"))
    expect(decoded["favorite"] as? Bool).to(beTrue())
    expect(decoded["location"] as? String).to(equal("YouTube"))
    expect(decoded["length"] as? String).to(equal("1 hour"))

    expect(decoded["seasonMaps"] as? [String]).to(equal(["...", ".S+.S"]))
    expect(decoded["watchedEpisodeMaps"] as? [String]).to(equal([".xx", "xxx."]))
  }

  @MainActor
  func test_Show_unstartedShowSerializesCorrectly() {
    let seasons: [Season] = [
      Season(
        number: 1,
        items: [
          NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: false),
          NumberedEpisode(index: 1, episodeIndex: 1, episodeNumber: 2, isWatched: false)
        ]),
      Season(
        number: 2,
        items: [
          NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: false),
          NumberedEpisode(index: 1, episodeIndex: 1, episodeNumber: 2, isWatched: false)
        ])
    ]
    let show = Show(id: 0, title: "", tvmazeId: "", favorite: .favorited, location: "", episodeLength: "",
                    seasons: seasons)
    let encoded = try! JSONEncoder().encode(ShowDTO.from(show))

    let decoded = try! JSONSerialization.jsonObject(with: encoded) as! NSDictionary
    expect(decoded["watchedEpisodeMaps"] as? [String]).to(equal(["..", ".."]))
  }

  @MainActor
  func test_Show_unstartedSeasonSerializesCorrectly() {
    let seasons: [Season] = [
      Season(
        number: 1,
        items: [
          NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: true),
          Separator(index: 1),
          NumberedEpisode(index: 2, episodeIndex: 1, episodeNumber: 2, isWatched: true)
        ]),
      Season(
        number: 2,
        items: [
          NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: false),
          Separator(index: 1),
          NumberedEpisode(index: 2, episodeIndex: 1, episodeNumber: 2, isWatched: false)
        ])
    ]
    let show = Show(id: 0, title: "", tvmazeId: "", favorite: .favorited, location: "", episodeLength: "",
                    seasons: seasons)
    let encoded = try! JSONEncoder().encode(ShowDTO.from(show))

    let decoded = try! JSONSerialization.jsonObject(with: encoded) as! NSDictionary
    expect(decoded["watchedEpisodeMaps"] as? [String]).to(equal(["xx", ".."]))
  }

  @MainActor
  func test_Season_fullyWatchedSeasonIsComplete() {
    let seasonItems: [SeasonItem] = [
      NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: true),
      Separator(index: 1),
      NumberedEpisode(index: 2, episodeIndex: 1, episodeNumber: 2, isWatched: true)
    ]
    let season = Season(number: 1, items: seasonItems)

    expect(season.isCompleted).to(beTrue())
  }

  @MainActor
  func test_Season_fullyWatchedSeasonIsIncomplete() {
    let seasonItems: [SeasonItem] = [
      NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: false),
      Separator(index: 1),
      NumberedEpisode(index: 2, episodeIndex: 1, episodeNumber: 2, isWatched: true)
    ]
    let season = Season(number: 1, items: seasonItems)

    expect(season.isCompleted).to(beFalse())
  }

  @MainActor
  func test_Show_markWatchedUpToEpisode() {
    let seasons: [Season] = [
      Season(
        number: 1,
        items: [
          NumberedEpisode(index: 0, episodeIndex: 0, episodeNumber: 1, isWatched: true),
          Separator(index: 1),
          NumberedEpisode(index: 2, episodeIndex: 1, episodeNumber: 2, isWatched: false)
        ]
      ),
      Season(
        number: 2,
        items: [
          SpecialEpisode(index: 0, episodeIndex: 0, isWatched: false),
          Separator(index: 1),
          NumberedEpisode(index: 2, episodeIndex: 1, episodeNumber: 1, isWatched: false),  // <- target episode
          NumberedEpisode(index: 3, episodeIndex: 2, episodeNumber: 2, isWatched: false),
          NumberedEpisode(index: 4, episodeIndex: 3, episodeNumber: 3, isWatched: true)
        ]
      ),
      Season(
        number: 3,
        items: [
          SpecialEpisode(index: 0, episodeIndex: 0, isWatched: false)
        ]
      )
    ]
    let show = Show(id: 0, title: "", tvmazeId: "", favorite: .unfavorited, location: "", episodeLength: "", 
                    seasons: seasons)

    let updatedEpisodes = show.markWatchedUpTo(targetEpisode: seasons[1].items[2] as! Episode)
    expect(updatedEpisodes).to(equal([
      EpisodeDescriptor(showId: 0, season: 1, episodeIndex: 1),
      EpisodeDescriptor(showId: 0, season: 2, episodeIndex: 0),
      EpisodeDescriptor(showId: 0, season: 2, episodeIndex: 1)
    ]))

    for season in seasons {
      for ep in season.items.compactMap({ $0 as? Episode }) {
        switch season.number {
          case 1: 
            expect(ep.isWatched).to(beTrue(), description: "season \(season.number), index \(ep.index)")
          case 2:
            switch ep.episodeIndex {
              case 0, 1, 3:
                expect(ep.isWatched).to(beTrue(), description: "season \(season.number), index \(ep.index)")
              case 2:
                expect(ep.isWatched).to(beFalse(), description: "season \(season.number), index \(ep.index)")
              default:
                fail()
            }
          case 3:
            expect(ep.isWatched).to(beFalse(), description: "season \(season.number), index \(ep.index)")
          default: fail()
        }
      }
    }
  }

  func test_EpisodeMetadata_TVmazeMetadataDeserializesNormalEpisodeCorrectly() {
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

  func test_EpisodeMetadata_TVmazeMetadataDeserializesSpecialEpisodeCorrectly() {
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
