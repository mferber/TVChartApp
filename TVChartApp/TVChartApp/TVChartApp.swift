import SwiftUI

@main
struct TVChartAppApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView(appData: AppData(shows: []))
    }
  }
}
