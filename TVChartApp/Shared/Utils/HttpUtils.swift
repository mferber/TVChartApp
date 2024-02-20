import Foundation

extension URLResponse {
  var isHttpOk: Bool {
    guard let rsp = self as? HTTPURLResponse else {
      return false
    }
    return (200..<300).contains(rsp.statusCode)
  }

  func validate() throws {
    if !self.isHttpOk {
      throw HttpError.notOk
    }
  }
}

enum HttpError: Error {
  case notOk
}
