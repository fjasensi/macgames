import Foundation

public enum LibrarySortOrder: String, Codable, CaseIterable, Sendable {
    case library
    case recentlyPlayed
}

/// Local library metadata, separate from each game's launch settings.
public struct LibraryPreferences: Codable, Equatable, Sendable {
    public var favorites: Set<String>
    public var lastPlayed: [String: Date]
    public var sortOrder: LibrarySortOrder

    public init(favorites: Set<String> = [], lastPlayed: [String: Date] = [:],
                sortOrder: LibrarySortOrder = .library) {
        self.favorites = favorites
        self.lastPlayed = lastPlayed
        self.sortOrder = sortOrder
    }

    static let defaultsKey = "libraryPreferences.v1"

    public static func load(from defaults: UserDefaults = .standard) -> LibraryPreferences {
        guard let data = defaults.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }

    public func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    public mutating func toggleFavorite(_ gameID: String) {
        if !favorites.insert(gameID).inserted { favorites.remove(gameID) }
    }

    private enum CodingKeys: String, CodingKey { case favorites, lastPlayed, sortOrder }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        favorites = try values.decodeIfPresent(Set<String>.self, forKey: .favorites) ?? []
        lastPlayed = try values.decodeIfPresent([String: Date].self, forKey: .lastPlayed) ?? [:]
        let order = try values.decodeIfPresent(String.self, forKey: .sortOrder)
        sortOrder = order.flatMap(LibrarySortOrder.init(rawValue:)) ?? .library
    }
}

/// A launch attempt is not play history. Only a newly observed running game records a date.
public struct LibraryActivity: Sendable {
    private var running: Set<String> = []

    public init() {}

    @discardableResult
    public mutating func observe(gameID: String, state: GameState, at date: Date,
                                 preferences: inout LibraryPreferences) -> Bool {
        guard state == .running else {
            running.remove(gameID)
            return false
        }
        guard running.insert(gameID).inserted else { return false }
        preferences.lastPlayed[gameID] = date
        return true
    }
}
