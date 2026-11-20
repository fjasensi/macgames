import Sparkle
import SwiftUI

struct MacGamesApp: App {
    /// Local fork builds stay on the code installed by their owner.
    private let updater: SPUStandardUpdaterController? = {
        guard Bundle.main.object(forInfoDictionaryKey: "MacGamesDisableUpdates") as? Bool != true else { return nil }
        return SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }()

    var body: some Scene {
        Window("MacGames", id: "main") {
            LibraryView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 740)
        .commands {
            CommandGroup(after: .appInfo) {
                if let updater {
                    Button("Check for Updates…") { updater.checkForUpdates(nil) }
                }
            }
        }
    }
}
