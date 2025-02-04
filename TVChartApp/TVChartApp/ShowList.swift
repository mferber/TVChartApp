import SwiftUI

struct ShowList: View {
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
    .background()
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

struct SeasonRow: View {
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
        .background(
          Color(UIColor.systemBackground)
            .mask(
              LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(maxOpacity), Color.clear]),
                startPoint: .center,
                endPoint: .trailing
              )
            )
        )
        .zIndex(1)

      ScrollView([.horizontal], showsIndicators: false) {
        HStack(spacing: EpisodeBoxSpecs.size / 4.0) {
          EpisodeRow(items: season.items)
          SeasonEnd(filled: season.isCompleted)
        }
      }
      .defaultScrollAnchor(.leading)
      .scrollClipDisabled()  // permit scrolling behind season numbers
    }
    .id(seasonRowId(showId: show.id, season: season.number))
  }
}

struct EpisodeRow: View {
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

struct SeasonEnd: View {
  var filled: Bool

  var body: some View {
    return Image(systemName: "rhombus\(filled ? ".fill" : "")")
      .foregroundStyle(.episodeBox).dynamicTypeSize(.xSmall)
  }
}

struct EpisodeButton: View {
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

struct EpisodeView: View {
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

struct EpisodeBox: View {
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

struct EpisodeLabel: View {
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

struct SeparatorView: View {
  var body: some View {
    Image(systemName: "plus")
      .imageScale(.small)
      .foregroundColor(.episodeBox)
      .frame(width: EpisodeBoxSpecs.size / 2.0, height: EpisodeBoxSpecs.size / 2.0)
  }
}

struct FavoritesToggle: View {
  @Binding var isOn: Bool
  @Environment(ContentView.DisplayState.self) var displayState

  var body: some View {
    Toggle(isOn: Bindable(displayState).showFavoritesOnly) { }
      .labelsHidden()
      .padding(20)
      .background(Color.white.opacity(0.5))
      .clipped(antialiased: false)
      .cornerRadius(20.0)
  }
}
