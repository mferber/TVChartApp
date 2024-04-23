import Foundation
import UIKit

extension String {
  func parseSynopsisHtml() async -> AttributedString {
    let html = sanitizeHtml()
    let data = Data(html.utf8)
    let documentType = NSAttributedString.DocumentType.html
    let encoding = String.Encoding.utf8.rawValue
    
    return await MainActor.run {  // crashes if not run on main thread
      if let nsAS = try? NSMutableAttributedString(
        data: data,
        options: [.documentType: documentType, .characterEncoding: encoding,],
        documentAttributes: nil
      ) {
        return AttributedString(nsAS.using(baseFont: UIFont.systemFont(ofSize: 15)))
      } else {
        return ""
      }
    }
  }

  private func sanitizeHtml() -> String {
    // some TVmaze synopses have bare </p><p> sequences for empty lines; these parse incorrectly
    return self.replacingOccurrences(of: "</p><p>", with: "<br /><br />")
  }
}
