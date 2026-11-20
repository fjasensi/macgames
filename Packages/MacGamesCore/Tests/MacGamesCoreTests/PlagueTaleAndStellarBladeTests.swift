import Foundation
import Testing
@testable import MacGamesCore

private struct AddedSteamGame: Sendable {
    let id: String
    let appID: String
    let folder: String
    let executable: String

    static let cases = [
        AddedSteamGame(id: "plague-tale-innocence", appID: "752590", folder: "A Plague Tale Innocence",
                      executable: "APlagueTaleInnocence_x64.exe"),
        AddedSteamGame(id: "plague-tale-requiem", appID: "1182900", folder: "A Plague Tale Requiem",
                      executable: "APlagueTaleRequiem_x64.exe"),
        AddedSteamGame(id: "plague-tale-resonance", appID: "2713000", folder: "Resonance A Plague Tale Legacy",
                      executable: "Resonance.exe"),
        AddedSteamGame(id: "stellar-blade", appID: "3489700", folder: "StellarBlade",
                      executable: "SB/Binaries/Win64/SB-Win64-Shipping.exe"),
    ]
}

@Suite(.serialized) struct PlagueTaleAndStellarBladeTests {
    @Test(arguments: AddedSteamGame.cases)
    private func gamesInstallAndPlayInTheExistingD3DMetalSteam(_ game: AddedSteamGame) throws {
        let profile = try #require(GameProfile.named(game.id))
        let env = try FakeEnvironment(profile); defer { env.cleanUp() }
        let runtime = env.runtime, paths = runtime.paths
        try env.installSteam()
        try EnvironmentSettings(hiDPI: true).save(to: paths)
        let diablo4 = GameRuntime(profile: .diablo4, root: paths.root, runtime: runtime.runtime)
        let previous = try diablo4.launchEnvironment()
        try SteamSession.begin(fingerprint: SteamLaunch.fingerprint(previous), paths: paths, environment: previous)
        env.live(["steam.exe"])

        #expect(paths.steamExe == diablo4.paths.steamExe)
        #expect(runtime.state() == .needsGame)
        try runtime.openForInstall()
        #expect(env.waitForCall(containing: "steam://install/\(game.appID)"))

        try write("""
        "AppState"
        {
            "appid" "\(game.appID)"
            "installdir" "\(game.folder)"
            "StateFlags" "4"
        }
        """, to: paths.steamapps.appendingPathComponent("appmanifest_\(game.appID).acf"))
        try write("game", to: paths.steamapps.appendingPathComponent("common/\(game.folder)/\(game.executable)"))
        #expect(runtime.state() == .ready)
        let launch = try runtime.launchEnvironment()
        #expect(launch["WINEDLLPATH"] == "\(paths.d3dmetal.path)/wine:\(paths.engineDLLs.path)")
        #expect(launch["CX_APPLEGPTK_LIBD3DSHARED_PATH"] == paths.d3dmetal.appendingPathComponent("external/libd3dshared.dylib").path)
        #expect(launch["WINEPREFIX"] == previous["WINEPREFIX"])
        try runtime.play(LaunchContext(width: 1920, height: 1080))
        #expect(env.waitForCall(containing: "-applaunch \(game.appID)"))
        #expect(!env.calls.contains("wineserver -k"), "these games can reuse the existing D3DMetal session")
        #expect(!env.calls.contains { $0.contains("SteamSetup.exe") })

        env.live(["steam.exe", profile.executableName])
        #expect(runtime.state() == .running)
        #expect(runtime.runningGameTitle() == profile.title)
        try runtime.waitForGameStart()
        var history = LibraryActivity()
        var preferences = LibraryPreferences()
        #expect(history.observe(gameID: profile.id, state: runtime.state(), at: Date(), preferences: &preferences))
        #expect(preferences.lastPlayed[profile.id] != nil)
    }

    @Test func stellarBladeTracksTheGameInsteadOfItsBootstrapper() throws {
        let env = try FakeEnvironment(.stellarBlade); defer { env.cleanUp() }
        let runtime = env.runtime, paths = runtime.paths
        try env.installSteam()
        try write("""
        "AppState"
        {
            "appid" "3489700"
            "installdir" "StellarBlade"
            "StateFlags" "4"
        }
        """, to: paths.appManifest)
        try write("bootstrapper", to: paths.installDir.appendingPathComponent("SB.exe"))
        try write("game", to: paths.installDir.appendingPathComponent("SB/Binaries/Win64/SB-Win64-Shipping.exe"))
        env.live(["steam.exe", "SB.exe"])
        #expect(runtime.state() == .ready)
        #expect(runtime.runningGameTitle() == nil)
        env.live(["steam.exe", "SB-Win64-Shipping.exe"])
        #expect(runtime.state() == .running)
        #expect(runtime.runningGameTitle() == "Stellar Blade")
    }
}
