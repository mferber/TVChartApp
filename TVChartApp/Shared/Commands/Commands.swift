import Foundation

struct CommandExecutor {
  /* FIXME private */ let backend: any BackendProtocol

  private func getContext() -> CommandContext {
    return CommandContext(backend: backend)
  }

  func execute(command: Command) async throws {
    return try await command.execute(context: getContext())
  }
}

struct CommandContext {
  let backend: BackendProtocol
}

protocol Command {
  func execute(context: CommandContext) async throws
}

struct MarkEpisodeWatchedCommand: Command {
  let episode: Episode
  let watched: Bool

  func execute(context: CommandContext) async throws {
    print("Marking watched")
    try await context.backend.updateEpisodeStatus(episode: episode, watched: watched)
  }
}

//class MarkWatchedUpToEpisodeCommand: Command {
//
//}
