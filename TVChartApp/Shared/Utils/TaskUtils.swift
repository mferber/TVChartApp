import Foundation

extension Task where Success == Never, Failure == Never {
  /// More convenient sleep
  public static func sleep(_ seconds: Double) async {
    do {
      try await Task.sleep(nanoseconds: UInt64(seconds * Double(1e9)))
    } catch {
      // don't care
    }
  }

  /// Convenience for testing API failures.
  public static func sleep(_ seconds: Double, thenThrow error: Error) async throws {
    await sleep(seconds)
    throw error
  }
}
