import Foundation

@Observable
class CommandExecutor {
  struct Context {
    let backend: BackendProtocol
    let metadataService: MetadataServiceProtocol
  }
  
  @ObservationIgnored let backend: any BackendProtocol
  @ObservationIgnored let metadataService: any MetadataServiceProtocol

  @ObservationIgnored var peekUndoDescription: String? {
    return undoStack.last?.undoDescription
  }

  var undoStack: [any UndoableCommand]
  var canUndo: Bool { !undoStack.isEmpty }
  
  init(backend: any BackendProtocol, metadataService: any MetadataServiceProtocol) {
    self.backend = backend
    self.metadataService = metadataService
    self.undoStack = []
  }

  private func getContext() -> Context {
    return Context(backend: backend, metadataService: metadataService)
  }

  func execute<C: Command>(_ command: C) async throws -> C.Output {
    do {
      let result = try await command.execute(context: getContext())
      if let undoable = command as? any UndoableCommand {
        undoStack.append(undoable)
      }
      return result
    }
  }

  func undo() async throws -> (any UndoableCommand)? {
    guard let command = undoStack.popLast() else { return nil }
    do {
      try await command.undo(context: getContext())
      return command
    } catch {
      undoStack.append(command)
      throw error
    }
  }
}

