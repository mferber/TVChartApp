import Foundation

extension URLResponse {
  func validate(_ data: Data?) throws {
    guard let rsp = self as? HTTPURLResponse else { return }

    if (200..<300).contains(rsp.statusCode) { return }
    let text: String?
    if let data {
      text = String(data: data, encoding: .utf8)
    } else {
      text = nil
    }
    throw HttpError.notOk(statusCode: rsp.statusCode, data: data, text: text)
  }
}

extension String {
  var urlPathEncoded: String {
    self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed)!
  }
}

enum HttpError: Error {
  case notOk(statusCode: Int, data: Data?, text: String?)
}
