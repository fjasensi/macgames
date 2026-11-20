import Foundation
import Testing
@testable import MacGamesCore

@Suite struct LibraryCatalogTests {
    @Test func defaultViewKeepsInstalledGamesFirstWithoutDuplicates() throws {
        let sections = LibraryCatalog.sections(states: ["diablo4": .ready, "skyrim-se": .running],
                                                preferences: LibraryPreferences())
        #expect(sections.first?.title == "Installed Games")
        #expect(sections.first?.games == [.diablo4, .skyrim])
        #expect(!sections.contains { $0.title == "Skyrim" })
        #expect(sections.allSatisfy { !$0.games.isEmpty })
        let games = sections.flatMap(\.games)
        #expect(games.count == GameProfile.all.count)
        #expect(Set(games.map(\.id)).count == games.count)
        let rockstar = try #require(sections.first { $0.title == "Rockstar" })
        #expect(rockstar.games == [.rdr2, .sanAndreas, .gta5])
    }

    @Test func searchIgnoresCaseAccentsAndSurroundingWhitespace() {
        let pokemon = GameProfile(id: "pokemon", title: "Pokémon Crystal", steamAppID: "1",
                                  installFolder: "Pokemon", executableRelativePath: "game.exe")
        let sections = LibraryCatalog.sections(profiles: [.nierAutomata, pokemon], states: ["pokemon": .ready],
                                                preferences: LibraryPreferences(), search: "  POKEMON  \n")
        #expect(sections.count == 1)
        #expect(sections.first?.title == "Installed Games")
        #expect(sections.first?.games == [pokemon])
    }

    @Test func favoritesCombineWithSearchAcrossEnvironments() {
        let preferences = LibraryPreferences(favorites: ["nier-automata", "diablo4-battlenet", "removed-game"])
        let sections = LibraryCatalog.sections(states: [:], preferences: preferences,
                                                search: "DIÁBLO", favoritesOnly: true)
        #expect(sections.count == 1)
        #expect(sections.first?.title == "Battle.net")
        #expect(sections.first?.games == [.diablo4BattleNet])
        #expect(preferences.lastPlayed.isEmpty, "browsing the library is not a play session")
    }

    @Test func unmatchedSearchAndEmptyFavoritesReturnNoSections() {
        #expect(LibraryCatalog.sections(states: [:], preferences: LibraryPreferences(),
                                        search: "not a game in this catalog").isEmpty)
        #expect(LibraryCatalog.sections(states: [:], preferences: LibraryPreferences(), favoritesOnly: true).isEmpty)
        #expect(LibraryCatalog.sections(states: [:], preferences: LibraryPreferences(), search: " \n ")
            .flatMap(\.games).count == GameProfile.all.count)
    }

    @Test func recentsOrderByDateThenCatalogPositionWithUnplayedGamesLast() {
        let profiles: [GameProfile] = [.aoe4, .skyrim, .diablo4BattleNet, .nierAutomata]
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let preferences = LibraryPreferences(lastPlayed: ["nier-automata": newer, "skyrim-se": older,
                                                          "diablo4-battlenet": older], sortOrder: .recentlyPlayed)
        let sections = LibraryCatalog.sections(profiles: profiles, states: [:], preferences: preferences)
        #expect(sections.count == 1)
        #expect(sections.first?.title == "Recently Played")
        #expect(sections.flatMap(\.games) == [.nierAutomata, .skyrim, .diablo4BattleNet, .aoe4])
    }

    @Test func recentsAndFavoritesShareTheVisibleShortcutOrder() {
        let preferences = LibraryPreferences(favorites: ["diablo4", "diablo4-battlenet"],
            lastPlayed: ["diablo4": Date(timeIntervalSince1970: 100),
                         "diablo4-battlenet": Date(timeIntervalSince1970: 200)], sortOrder: .recentlyPlayed)
        let visible = LibraryCatalog.sections(states: [:], preferences: preferences,
                                               search: "diablo", favoritesOnly: true).flatMap(\.games)
        #expect(visible.map(\.id) == ["diablo4-battlenet", "diablo4"])
    }

    @Test func recentsWithoutHistoryUseTheCatalogOrder() {
        let sections = LibraryCatalog.sections(states: [:], preferences: LibraryPreferences(sortOrder: .recentlyPlayed))
        #expect(sections.flatMap(\.games) == GameProfile.all)
    }
}

@Suite struct LibraryPreferencesTests {
    @Test func favoritesHistoryAndOrderSurviveReloadWithoutChangingSelection() throws {
        let suite = "MacGames.LibraryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("nier-automata", forKey: "selectedGame")
        var preferences = LibraryPreferences(lastPlayed: ["nier-automata": Date(timeIntervalSince1970: 1_000)],
                                             sortOrder: .recentlyPlayed)
        preferences.toggleFavorite("diablo4")
        preferences.toggleFavorite("nier-automata")
        preferences.toggleFavorite("diablo4")
        preferences.save(to: defaults)

        let reloaded = LibraryPreferences.load(from: defaults)
        #expect(reloaded == preferences)
        #expect(reloaded.favorites == ["nier-automata"])
        #expect(defaults.string(forKey: "selectedGame") == "nier-automata")
    }

    @Test func unreadablePreferencesFallBackToUsableDefaults() throws {
        let suite = "MacGames.LibraryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(LibraryPreferences.load(from: defaults) == LibraryPreferences())
        defaults.set(Data("invalid json".utf8), forKey: LibraryPreferences.defaultsKey)
        #expect(LibraryPreferences.load(from: defaults) == LibraryPreferences())
    }

    @Test func unknownSortModesPreserveFavoritesAndMissingFieldsUseDefaults() throws {
        let data = Data(#"{"favorites":["nier-automata"],"sortOrder":"future-order"}"#.utf8)
        let preferences = try JSONDecoder().decode(LibraryPreferences.self, from: data)
        #expect(preferences.favorites == ["nier-automata"])
        #expect(preferences.sortOrder == .library)
        #expect(preferences.lastPlayed.isEmpty)
    }
}

@Suite struct LibraryActivityTests {
    @Test(arguments: [GameState.notSetUp, .needsSteam, .needsGame, .installing, .ready])
    func nonRunningStatesNeverCreatePlayHistory(_ state: GameState) {
        var preferences = LibraryPreferences()
        var activity = LibraryActivity()
        #expect(!activity.observe(gameID: "nier-automata", state: state, at: Date(), preferences: &preferences))
        #expect(preferences.lastPlayed.isEmpty)
    }

    @Test func pollsKeepTheStartDateAndANewSessionUpdatesIt() {
        var preferences = LibraryPreferences()
        var activity = LibraryActivity()
        let first = Date(timeIntervalSince1970: 100)
        let later = Date(timeIntervalSince1970: 200)
        #expect(activity.observe(gameID: "nier-automata", state: .running, at: first, preferences: &preferences))
        #expect(!activity.observe(gameID: "nier-automata", state: .running, at: later, preferences: &preferences))
        #expect(preferences.lastPlayed["nier-automata"] == first)
        activity.observe(gameID: "nier-automata", state: .ready, at: later, preferences: &preferences)
        #expect(activity.observe(gameID: "nier-automata", state: .running, at: later, preferences: &preferences))
        #expect(preferences.lastPlayed["nier-automata"] == later)
    }

    @Test func gamesInDifferentEnvironmentsKeepIndependentHistory() {
        var preferences = LibraryPreferences()
        var activity = LibraryActivity()
        let first = Date(timeIntervalSince1970: 100)
        let later = Date(timeIntervalSince1970: 200)
        activity.observe(gameID: "diablo4", state: .running, at: first, preferences: &preferences)
        activity.observe(gameID: "overwatch", state: .running, at: later, preferences: &preferences)
        activity.observe(gameID: "diablo4", state: .ready, at: later, preferences: &preferences)
        #expect(!activity.observe(gameID: "overwatch", state: .running, at: Date(), preferences: &preferences))
        #expect(preferences.lastPlayed == ["diablo4": first, "overwatch": later])
    }
}
