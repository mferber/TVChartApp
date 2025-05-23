import Foundation

@MainActor
protocol Command {
  associatedtype Output
  func execute(context: CommandExecutor.Context) async throws -> Output
}

protocol UndoableCommand: Command {
  func execute(context: CommandExecutor.Context) async throws
  func undo(context: CommandExecutor.Context) async throws
  var undoDescription: String { get }
}

extension UndoableCommand {
  var undoDescription: String { "(unidentified action)"}

  func undo(context: CommandExecutor.Context) async throws {
    throw TVChartError.general("Undo not implemented for this action")
  }
}

struct LoadData: Command {
  func execute(context: CommandExecutor.Context) async throws -> AppData {
    return AppData(shows: try await context.backend.fetch())
  }
}

struct LoadMetadata: Command {
  let episode: Episode

  func execute(context: CommandExecutor.Context) async throws -> EpisodeMetadata {
    return try await context.metadataService.getEpisodeMetadata(
      forShow: episode.season.show,
      season: episode.season.number,
      episodeIndex: episode.episodeIndex
    )
  }
}

struct UpdateEpisodeStatus: UndoableCommand {
  let episode: Episode
  let watched: Bool

  var undoDescription: String {
    "Mark Episode \(watched ? "Watched" : "Unwatched")"
  }

  func execute(context: CommandExecutor.Context) async throws {
    do {
      try await context.backend.updateEpisodeStatus(episode: episode, watched: watched)
    } catch {
      // revert UI
      episode.isWatched = !episode.isWatched
      throw error
    }
  }

  func undo(context: CommandExecutor.Context) async throws {
    episode.isWatched = !episode.isWatched
    do {
      try await context.backend.updateEpisodeStatus(episode: episode, watched: !watched)
    } catch {
      // revert UI
      episode.isWatched = !episode.isWatched
      throw error
    }
  }
}

class MarkWatchedUpTo: UndoableCommand {
  let episode: Episode
  var updatedEpisodeDescriptors: [EpisodeDescriptor] = []

  init(episode: Episode) {
    self.episode = episode
  }

  func execute(context: CommandExecutor.Context) async throws {
    do {
      updatedEpisodeDescriptors = episode.season.show.markWatchedUpTo(targetEpisode: episode)
      try await context.backend.updateEpisodeStatuses(watched: updatedEpisodeDescriptors, unwatched: [])
    } catch {
      // revert UI
      if let show = episode.season.show {
        let episodes = updatedEpisodeDescriptors.map { descriptor in
          return show.seasons[safe: descriptor.season - 1]?
            .items.compactMap { $0 as? Episode }
            .first { $0.episodeIndex == descriptor.episodeIndex }
        }.compactMap { $0 }

        for ep in episodes {
          ep.isWatched = false
        }
      }
      throw error
    }
  }

  var undoDescription: String {
    "Mark \(updatedEpisodeDescriptors.count) Episode\(updatedEpisodeDescriptors.count == 1 ? "" : "s") Watched"
  }

  func undo(context: CommandExecutor.Context) async throws {
    guard let show = episode.season.show else { return }

    let episodes = updatedEpisodeDescriptors.map { descriptor in
      return show.seasons[safe: descriptor.season - 1]?
        .items.compactMap { $0 as? Episode }
        .first { $0.episodeIndex == descriptor.episodeIndex }
    }.compactMap { $0 }
    for ep in episodes {
      ep.isWatched = false
    }

    do {
      try await context.backend.updateEpisodeStatuses(watched: [], unwatched: updatedEpisodeDescriptors)
    } catch {
      // revert UI

      for ep in episodes {
        ep.isWatched = true
      }

      throw error
    }

  }
}
