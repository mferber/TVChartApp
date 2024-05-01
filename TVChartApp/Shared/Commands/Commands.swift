import Foundation

struct CommandExecutor {
  /* FIXME private */ let backend: any BackendProtocol

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
    try await context.backend.updateEpisodeStatus(episode: episode, watched: watched)
  }
}

//class MarkWatchedUpToEpisodeCommand: Command {
//
//}
