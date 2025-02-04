import SwiftUI

struct ShowListView: View {
  @Environment(ContentView.DisplayState.self) var displayState
  @Environment(AppData.self) var appData

  var body: some View {
    let displayShows = displayState.showFavoritesOnly ? appData.shows.favoritesOnly : appData.shows
    @Bindable var displayState = displayState

    VStack(alignment: .leading, spacing: 20) {
      ForEach(displayShows) { show in
        VStack(alignment: .leading) {

          // Show header view id is the show title
          Text(show.title)
            .font(.title2)
            .bold()
            .padding([.leading])
            .id(show.title)

          HStack(spacing: 5) {
            Image(systemName: show.isFavorite ? "heart.fill" : "heart")
              .foregroundColor(Color.accentColor)
            Text(show.location + ", " + show.episodeLength)
          }.padding([.leading])

          ForEach(show.seasons) {
            SeasonRow(show: show, season: $0)
          }
        }
      }
    }
    .padding([.top, .bottom])
    .contentShape(Rectangle())  // maximizes tappable background area
    .onTapGesture { displayState.isPresentingSelectedEpisode = false }
    .sheet(
      isPresented: $displayState.isPresentingSelectedEpisode,
      onDismiss: { displayState.selectedEpisodeDescriptor = nil }
    ) {
      if let descriptor = displayState.selectedEpisodeDescriptor {
        EpisodeDetailView(episodeDescriptor: descriptor)
          .presentationDetents([.fraction(0.4), .large])
          .presentationContentInteraction(.scrolls)
          .presentationBackgroundInteraction(.enabled(upThrough: .large))
          .presentationDragIndicator(.automatic)
          .presentationBackground(.thinMaterial)
      }
      Spacer()
    }
  }
}

private struct SeasonRow: View {
  let show: Show
  let season: Season
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    let maxOpacity = colorScheme == .dark ? 0.5 : 0.9

    // SeasonRow view id uses showId and seasonId
    HStack(spacing: 0) {
      Text(String(season.id))
        .bold()
        .frame(width: EpisodeBoxSpecs.size, height: EpisodeBoxSpecs.size, alignment: .trailing)
        .padding(.trailing, EpisodeBoxSpecs.size / 2.0)

      ScrollView([.horizontal], showsIndicators: false) {
        HStack(spacing: EpisodeBoxSpecs.size / 4.0) {
          EpisodeRow(items: season.items)
          SeasonEnd(filled: season.isCompleted)
        }
      }
      .defaultScrollAnchor(.leading)
    }
    .id(seasonRowId(showId: show.id, season: season.number))
  }
}

private struct EpisodeRow: View {
  let items: [SeasonItem]

  var body: some View {
    HStack(spacing: EpisodeBoxSpecs.size / 8.0) {
      ForEach(items) { item in
        switch item {
          case let episode as Episode:
            EpisodeButton(episode: episode)
          case is Separator:
            SeparatorView()
          default:
            EmptyView()
        }
      }
    }
  }
}

private struct SeasonEnd: View {
  var filled: Bool

  var body: some View {
    return Image(systemName: "rhombus\(filled ? ".fill" : "")")
      .foregroundStyle(.episodeBox).dynamicTypeSize(.xSmall)
  }
}

private struct EpisodeButton: View {
  let episode: Episode
  @Environment(ContentView.DisplayState.self) var displayState

  var body: some View {
    Button {
      displayState.selectedEpisodeDescriptor = episode.descriptor
      displayState.isPresentingSelectedEpisode = true
    } label: {
      EpisodeView(
        episode: episode,
        isSelected: displayState.selectedEpisodeDescriptor?.matches(episode) ?? false
      )
    }
  }
}

private struct EpisodeView: View {
  let episode: Episode
  let isSelected: Bool

  var body: some View {
    let caption: AnyView
    if let numbered = episode as? NumberedEpisode {
      caption = AnyView(Text(String(numbered.episodeNumber)).font(EpisodeBoxSpecs.font))

    } else {
      caption = AnyView(Image(systemName: "star.fill").font(EpisodeBoxSpecs.font))
    }

    return ZStack {
      EpisodeBox(episode: episode, isSelected: isSelected)
      EpisodeLabel(episode: episode, caption: caption, isSelected: isSelected)
    }
    .animation(.easeInOut.speed(3), value: episode.isWatched)
    .animation(.easeInOut.speed(3), value: isSelected)
  }
}

private struct EpisodeBox: View {
  let episode: Episode
  let isSelected: Bool

  var body: some View {
   let strokeColor: Color, fillColor: Color

    switch (episode.isWatched, isSelected) {
      case (false, false):
        strokeColor = .episodeBox
        fillColor = .clear
      case (true, false):
        strokeColor = .episodeBox
        fillColor = .episodeBox
      case (false, true):
        strokeColor = .accentColor
        fillColor = .clear
      case (true, true):
        strokeColor = .accentColor
        fillColor = .accentColor
    }

    return RoundedRectangle(cornerRadius: EpisodeBoxSpecs.cornerRadius, style: .circular)
      .fill(fillColor)
      .strokeBorder(strokeColor, lineWidth: EpisodeBoxSpecs.borderWidth)
      .frame(width: EpisodeBoxSpecs.size, height: EpisodeBoxSpecs.size)
  }
}

private struct EpisodeLabel: View {
  let episode: Episode
  let caption: AnyView
  let isSelected: Bool

  var body: some View {
    let fgColor: Color
    switch (episode.isWatched, isSelected) {
      case (true, _): fgColor = .watchedText
      case (false, true): fgColor = .accentColor
      case (false, false): fgColor = .unwatchedText
    }

    return caption.foregroundColor(fgColor)
  }
}

private struct SeparatorView: View {
  var body: some View {
    Image(systemName: "plus")
      .imageScale(.small)
      .foregroundColor(.episodeBox)
      .frame(width: EpisodeBoxSpecs.size / 2.0, height: EpisodeBoxSpecs.size / 2.0)
  }
}

#if DEBUG
@MainActor
private func previewData() throws -> [Show] {
  let sampleDataUrl = Bundle.main.url(forResource: "previewData", withExtension: "json")
  guard let sampleDataUrl else {
    throw TVChartError.general("no URL to sample data")
  }
  let json = try? Data(contentsOf: sampleDataUrl)
  guard let json else {
    throw TVChartError.general("can't read sample data")
  }
  var content: [Show]!
  do {
    try content = JSONDecoder().decode([ShowDTO].self, from: json).map { $0.toShow() }
  } catch {
    throw TVChartError.general("can't parse JSON: \(error)")
  }
  return content.sortedByTitle
}
#endif

#Preview {
  do {
    var shows: [Show] = []
    try MainActor.assumeIsolated {
      shows = try previewData()
    }
    let backend = BackendStub()
    backend.fetchResult = shows

    return ScrollView {
      ShowListView()
        .environment(TVChartApp.AppState())
        .environment(ContentView.DisplayState(commandExecutor: CommandExecutor(backend: backend, metadataService: MetadataServiceStub())))
        .environment(AppData(shows: shows))
        .tint(.accent)
    }
  } catch {
    let desc = switch error {
      case let e as DisplayableError: e.displayDescription
      default: "\(error)"
    }
    print(desc)
    return Text(desc)
  }
}
