import Foundation

enum Loadable<T> {
  case loading
  case ready(T)
  case error(Error)
}
