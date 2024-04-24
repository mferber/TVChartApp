import Foundation
import UIKit

extension NSMutableAttributedString {
  // Converts the attributed string's base font to the provided font and color, preserving
  // all traits listed in applyTraitsFromFont()
  // Based on code from https://stackoverflow.com/a/58996779
  func using(baseFont: UIFont, color: UIColor = .label) -> NSMutableAttributedString {
    enumerateAttribute(
      NSAttributedString.Key.font,
      in: NSMakeRange(0, length),
      options: .longestEffectiveRangeNotRequired
    ) { (value, range, stop) in
      if let originalFont = value as? UIFont, let newFont = applyTraitsFromFont(originalFont, to: baseFont) {
        addAttribute(NSAttributedString.Key.font, value: newFont, range: range)
        addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
      }
    }
    return self
  }

  private func applyTraitsFromFont(_ originalFont: UIFont, to newFont: UIFont) -> UIFont? {
    let originalTraits = originalFont.fontDescriptor.symbolicTraits
    var traits = newFont.fontDescriptor.symbolicTraits

    for trait: UIFontDescriptor.SymbolicTraits in [.traitBold, .traitItalic] {
      if originalTraits.contains(trait) {
        traits.insert(trait)
      }
    }

    if let fontDescriptor = newFont.fontDescriptor.withSymbolicTraits(traits) {
      return UIFont.init(descriptor: fontDescriptor, size: 0)
    }
    return originalFont
  }
}

