import Foundation

struct CommandExecutor {
  private let backend: any BackendProtocol

  init(backend: any BackendProtocol) {
    self.backend = backend
  }
  
  private func getContext() -> CommandContext {
    return CommandContext(backend: backend)
  }

  func execute<C: Command>(_ command: C) async throws -> C.Output {
    return try await command.execute(context: getContext())
  }
}

struct CommandContext {
  let backend: BackendProtocol
}

protocol Command {
  associatedtype Output
  func execute(context: CommandContext) async throws -> Output
}

struct LoadData: Command {
  func execute(context: CommandContext) async throws -> AppData {
    return AppData(shows: try await context.backend.fetch())
  }
}

struct UpdateEpisodeStatus: Command {
  let episode: Episode
  let watched: Bool

  func execute(context: CommandContext) async throws {
    do {
      try await context.backend.updateEpisodeStatus(episode: episode, watched: watched)
    } catch {
      // revert UI
      await MainActor.run {
        episode.isWatched = !episode.isWatched
      }
      throw error
    }
  }
}

struct MarkWatchedUpTo: Command {
  let episode: Episode

  func execute(context: CommandContext) async throws {
    var updatedEpisodeDescriptors: [EpisodeDescriptor]?
    do {

      updatedEpisodeDescriptors = await episode.season.show.markWatchedUpTo(targetEpisode: episode)
      if let descriptors = updatedEpisodeDescriptors {
        try await context.backend.updateEpisodeStatuses(watched: descriptors, unwatched: [])
      }
    } catch {
      // revert UI
      if let descriptors = updatedEpisodeDescriptors, let show = await episode.season.show {
        await MainActor.run {

          let episodes = descriptors.map { descriptor in
            return show.seasons[safe: descriptor.season - 1]?
              .items.compactMap { $0 as? Episode }
              .first { $0.episodeIndex == descriptor.episodeIndex }
          }.compactMap { $0 }

          for ep in episodes {
            ep.isWatched = false
          }
        }
      }
      throw error
    }
  }
}
