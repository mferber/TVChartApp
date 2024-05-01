import Foundation

struct CommandExecutor {
  struct Context {
    let backend: BackendProtocol
  }
  
  private let backend: any BackendProtocol

  init(backend: any BackendProtocol) {
    self.backend = backend
  }

  private func getContext() -> Context {
    return Context(backend: backend)
  }

  func execute<C: Command>(_ command: C) async throws -> C.Output {
    return try await command.execute(context: getContext())
  }
}

