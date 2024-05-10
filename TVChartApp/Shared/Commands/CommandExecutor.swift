import Foundation

struct CommandExecutor {
  struct Context {
    let backend: BackendProtocol
    let metadataService: MetadataServiceProtocol
  }
  
  let backend: any BackendProtocol
  let metadataService: any MetadataServiceProtocol

  private func getContext() -> Context {
    return Context(backend: backend, metadataService: metadataService)
  }

  func execute<C: Command>(_ command: C) async throws -> C.Output {
    return try await command.execute(context: getContext())
  }
}

