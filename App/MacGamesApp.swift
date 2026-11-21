import Sparkle
import SwiftUI

struct MacGamesApp: App {
    /// Local fork builds stay on the code installed by their owner.
    private let updater: SPUStandardUpdaterController? = {
        guard Bundle.main.object(forInfoDictionaryKey: "MacGamesDisableUpdates") as? Bool != true else { return nil }
        return SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }()

    var body: some Scene {
        Window(ForkIdentity.name, id: "main") {
            LibraryView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 740)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(ForkIdentity.name)") { ForkIdentity.showAbout() }
            }
            CommandGroup(after: .appInfo) {
                if let updater {
                    Button("Check for Updates…") { updater.checkForUpdates(nil) }
                }
            }
            CommandGroup(replacing: .help) {
                Link("MacGames Fork Help", destination: ForkIdentity.repository)
                Link("Report an Issue…", destination: ForkIdentity.issues)
                Link("Contribute…", destination: ForkIdentity.contributing)
                Link("Fork Releases…", destination: ForkIdentity.releases)
                Divider()
                Link("Original MacGames Project", destination: ForkIdentity.upstream)
            }
        }
    }
}
