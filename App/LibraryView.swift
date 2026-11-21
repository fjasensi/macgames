import AppKit
import MacGamesCore
import SwiftUI

struct LibraryView: View {
    @State private var library = LibraryModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(library: library)
                .frame(width: 280)
            if let game = library.selected {
                GameDetailView(game: game)
                    .id(game.id)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 18)).combined(with: .scale(scale: 0.985, anchor: .top)),
                        removal: .opacity))
            }
        }
        .background { Backdrop(game: library.selected) }
        .ignoresSafeArea()
        .frame(minWidth: 980, minHeight: 620)
        .environment(\.colorScheme, .dark)
        .task { await library.poll() }
        .background {
            // ⌘1…⌘9 select a game by its place in the list.
            ForEach(Array(library.ordered.prefix(9).enumerated()), id: \.offset) { index, _ in
                Button("") { withAnimation(Motion.switchGame) { library.select(index: index) } }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    .hidden()
            }
            Button("Toggle Favorite for Selected Game") { library.toggleFavorite(library.selectedID) }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(library.selected == nil)
                .hidden()
            Button("Show Favorites Only") { library.favoritesOnly.toggle() }
                .keyboardShortcut("f", modifiers: [.command, .option])
                .hidden()
        }
    }
}

/// The selected game's hero art, blurred into the whole window.
private struct Backdrop: View {
    let game: GameModel?

    var body: some View {
        ZStack {
            Color.black
            if let game {
                ArtImage(url: game.profile.art?.hero, focus: game.profile.heroFocus)
                    .blur(radius: 80)
                    .saturation(1.25)
                    .opacity(0.55)
                    .id(game.id)
                    .transition(.opacity)
            }
            Color.black.opacity(0.35)
        }
        .animation(.easeInOut(duration: 0.8), value: game?.id)
    }
}

private struct Sidebar: View {
    @Bindable var library: LibraryModel
    @Namespace private var selection
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Library")
                .font(.system(size: 22, weight: .heavy).width(.condensed))
                .padding(.leading, Space.s)
                .padding(.top, 48)
                .padding(.bottom, Space.m)
            libraryControls
                .padding(.bottom, Space.m)
            if library.sortOrder == .recentlyPlayed && library.preferences.value.lastPlayed.isEmpty {
                Text("Play a game to start your history.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.horizontal, Space.s)
                    .padding(.bottom, Space.s)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xs) {
                    if library.sections.isEmpty { emptyLibrary }
                    ForEach(Array(library.sections.enumerated()), id: \.element.title) { index, section in
                        Text(section.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, Space.s)
                            .padding(.top, index == 0 ? 0 : Space.m)
                        ForEach(section.games) { game in
                            GameRow(game: game, selected: game.id == library.selectedID,
                                    favorite: library.isFavorite(game.id), lastPlayed: library.lastPlayed(game.id),
                                    showsHistory: library.sortOrder == .recentlyPlayed, namespace: selection,
                                    select: { withAnimation(Motion.switchGame) { library.selectedID = game.id } },
                                    toggleFavorite: { library.toggleFavorite(game.id) })
                        }
                    }
                }
            }
            .scrollIndicators(.never)
            Spacer(minLength: 0)
            SteamControl(library: library)
                .padding(.bottom, Space.l)
        }
        .padding(.horizontal, Space.sidebarInset)
        .background(.ultraThinMaterial.opacity(0.7))
        .overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.06)).frame(width: 1) }
        .background {
            Button("Search games") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
    }

    private var libraryControls: some View {
        VStack(spacing: Space.s) {
            HStack(spacing: Space.s) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search games", text: $library.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .accessibilityLabel("Search games")
                    .onSubmit { searchFocused = false }
                    .onExitCommand {
                        if library.searchText.isEmpty { searchFocused = false }
                        else { library.searchText = "" }
                    }
                if !library.searchText.isEmpty {
                    Button { library.searchText = ""; searchFocused = true } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .help("Clear search")
                }
            }
            .padding(Space.s)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.07)))

            HStack {
                Toggle(isOn: $library.favoritesOnly) {
                    Label("Favorites", systemImage: "star.fill")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .accessibilityLabel("Show favorites only")
                .help("Show favorites only (⌘⌥F)")
                Spacer(minLength: Space.s)
                Menu {
                    Picker("Sort games", selection: $library.sortOrder) {
                        Text("Library order").tag(LibrarySortOrder.library)
                        Text("Recently played").tag(LibrarySortOrder.recentlyPlayed)
                    }
                } label: {
                    Label(library.sortOrder == .library ? "Library" : "Recent", systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Sort games")
                .accessibilityValue(library.sortOrder == .library ? "Library order" : "Recently played")
                .help("Sort games")
            }
        }
    }

    private var emptyLibrary: some View {
        VStack(spacing: Space.m) {
            Image(systemName: library.favoritesOnly ? "star" : "magnifyingglass")
                .font(.system(size: 24)).foregroundStyle(.secondary)
            Text(library.favoritesOnly && library.searchText.isEmpty ? "No favorites yet" : "No games found")
                .font(.system(size: 13, weight: .semibold))
            Text(library.favoritesOnly
                 ? "Use a game's star to add a favorite, or clear the filters to see all games."
                 : "Try another title or clear your search.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Clear filters", action: library.clearFilters)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
        .padding(.horizontal, Space.s)
    }
}

private struct GameRow: View {
    let game: GameModel
    let selected: Bool
    let favorite: Bool
    let lastPlayed: Date?
    let showsHistory: Bool
    let namespace: Namespace.ID
    let select: () -> Void
    let toggleFavorite: () -> Void
    @State private var hovering = false

    private var historySummary: String {
        lastPlayed.map { "Played " + $0.formatted(date: .abbreviated, time: .shortened) }
            ?? "No play history yet"
    }

    var body: some View {
        HStack(spacing: Space.xs) {
            Button(action: select) {
                HStack(spacing: Space.m) {
                    ArtImage(url: game.profile.art?.portrait)
                        .frame(width: 40, height: 60)
                        .background(game.profile.accent.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(game.profile.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            StatusDot(state: game.state, accent: game.profile.accent)
                            Text(game.busy ? (game.step?.title ?? "Working…") : game.state.shortSummary)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .contentTransition(.opacity)
                                .animation(Motion.morph, value: game.state)
                        }
                        if showsHistory {
                            Text(historySummary)
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(game.profile.title), \(game.state.shortSummary)\(showsHistory ? ", " + historySummary : "")")
            Button(action: toggleFavorite) {
                Image(systemName: favorite ? "star.fill" : "star")
                    .foregroundStyle(favorite ? Color.yellow : Color.secondary)
                    .frame(width: 26, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(favorite ? "Remove" : "Add") \(game.profile.title) \(favorite ? "from" : "to") favorites")
            .accessibilityValue(favorite ? "Favorite" : "Not a favorite")
            .help((favorite ? "Remove from favorites" : "Add to favorites") + (selected ? " (⌘⇧F)" : ""))
        }
        .padding(Space.s)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 10)
                    .fill(game.profile.accent.opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(game.profile.accent.opacity(0.45), lineWidth: 1))
                    .matchedGeometryEffect(id: "selection", in: namespace)
            } else if hovering {
                RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { over in withAnimation(.easeOut(duration: 0.15)) { hovering = over } }
        .contextMenu {
            Button(favorite ? "Remove from Favorites" : "Add to Favorites", action: toggleFavorite)
            Divider()
            Button(game.state.actionTitle(launcher: game.launcherName), action: game.primaryAction).disabled(game.locked)
            Button("Open \(game.launcherName)", action: game.openSteam).disabled(!game.steamAvailable || game.locked)
            Divider()
            Button("Show logs", action: game.showLogs)
        }
    }
}

/// Green when ready, pulsing in the game's color while it plays.
struct StatusDot: View {
    let state: GameState
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var color: Color {
        switch state {
        case .ready: .green
        case .running: accent
        case .installing: .blue
        default: .secondary
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .overlay {
                if state == .running && !reduceMotion {
                    Circle().stroke(color, lineWidth: 1.5)
                        .phaseAnimator([false, true]) { ring, expanded in
                            ring.scaleEffect(expanded ? 2.6 : 1).opacity(expanded ? 0 : 0.8)
                        } animation: { expanded in expanded ? .easeOut(duration: 1.4) : .linear(duration: 0) }
                }
            }
            .animation(Motion.morph, value: state)
    }
}

/// The one Steam client every game shares.
private struct SteamControl: View {
    let library: LibraryModel

    var body: some View {
        let game = library.selected
        let env = library.selectedEnvironment
        let running = library.launcherRunning(env)
        let installed = game?.steamAvailable == true
        let name = env.launcher == .battleNet ? "Battle.net" : "Steam"
        let status = library.launcher[env.id] ?? SteamStatus(account: nil, downloads: [])
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                SteamIcon(image: env.launcher == .steam ? library.steamIcons[env.id] : nil, running: running)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name).font(.system(size: 14, weight: .bold))
                        if running {
                            Circle().fill(.green).frame(width: 6, height: 6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    Text(subtitle(running: running, installed: installed, name: name, account: status.account))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
            }

            ForEach(status.downloads, id: \.profile.id) { download in
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Downloading \(download.profile.title)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    DownloadBar(progress: download.progress, accent: download.profile.accent)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: Space.s) {
                Button { game?.openSteam() } label: {
                    Label("Open \(name)", systemImage: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(Capsule().fill(.white.opacity(0.12)))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(!installed || game?.locked == true)
                .keyboardShortcut("o", modifiers: .command)
                .help("Open the \(name) window (⌘O)")

                if running {
                    Button { withAnimation(Motion.switchGame) { library.requestStopSteam() } } label: {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.white.opacity(0.12)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(game?.locked ?? true)
                    .help("Stop \(name) and every game it runs")
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(Space.m)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.09)))
        .animation(Motion.morph, value: running)
        .animation(Motion.morph, value: status.downloads.map(\.profile.id))
        .animation(Motion.morph, value: env.id)
    }

    private func subtitle(running: Bool, installed: Bool, name: String, account: SteamAccount?) -> String {
        if !installed { return "Set up a game to install \(name)" }
        if running, let persona = account?.personaName { return "Signed in as \(persona)" }
        return running ? "Running" : "Not running"
    }
}

/// Steam's own round icon from the installed client; a symbol until it exists.
private struct SteamIcon: View {
    let image: NSImage?
    let running: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            } else {
                Circle().fill(.white.opacity(0.1))
                Image(systemName: "gamecontroller.fill").font(.system(size: 15)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 36, height: 36)
        .saturation(running ? 1 : 0.2)
        .opacity(running ? 1 : 0.75)
        .shadow(color: running ? Color(red: 0.3, green: 0.55, blue: 0.95).opacity(0.5) : .clear, radius: running && !reduceMotion ? 8 : 0)
        .animation(.easeInOut(duration: 0.6), value: running)
    }
}
