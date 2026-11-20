import Foundation

/// Presentation order shared by the sidebar and its numbered keyboard shortcuts.
public enum LibraryCatalog {
    public struct Section: Equatable, Sendable {
        public let title: String
        public let games: [GameProfile]

        public init(title: String, games: [GameProfile]) {
            self.title = title
            self.games = games
        }
    }

    public static func sections(profiles: [GameProfile] = GameProfile.all,
                                states: [String: GameState], preferences: LibraryPreferences,
                                search: String = "", favoritesOnly: Bool = false) -> [Section] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = profiles.filter { profile in
            (!favoritesOnly || preferences.favorites.contains(profile.id))
                && (query.isEmpty || profile.title.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }
        guard !visible.isEmpty else { return [] }

        if preferences.sortOrder == .recentlyPlayed {
            let ordered = visible.enumerated().sorted { lhs, rhs in
                switch (preferences.lastPlayed[lhs.element.id], preferences.lastPlayed[rhs.element.id]) {
                case let (left?, right?) where left != right: return left > right
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.offset < rhs.offset
                }
            }.map(\.element)
            return [Section(title: "Recently Played", games: ordered)]
        }

        let installed = visible.filter { states[$0.id] == .ready || states[$0.id] == .running }
        let installedIDs = Set(installed.map(\.id))
        var result = installed.isEmpty ? [] : [Section(title: "Installed Games", games: installed)]
        for environment in GameEnvironment.all {
            let remaining = visible.filter {
                $0.gameEnvironment.id == environment.id && !installedIDs.contains($0.id)
            }
            guard !remaining.isEmpty else { continue }
            if let existing = result.firstIndex(where: { $0.title == environment.group }) {
                let section = result[existing]
                result[existing] = Section(title: section.title, games: section.games + remaining)
            } else {
                result.append(Section(title: environment.group, games: remaining))
            }
        }
        return result
    }
}
