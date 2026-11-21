import AppKit

enum ForkIdentity {
    static let name = "MacGames Fork"
    static let repository = URL(string: "https://github.com/fjasensi/macgames")!
    static let releases = repository.appendingPathComponent("releases")
    static let issues = repository.appendingPathComponent("issues")
    static let contributing = repository.appendingPathComponent("blob/main/CONTRIBUTING.md")
    static let upstream = URL(string: "https://github.com/tarikbc/macgames")!

    @MainActor static func showAbout() {
        let credits = NSMutableAttributedString(string: """
        Independent fork maintained by fjasensi.
        Derived from MacGames by Tarik Caramanico.

        Releases and support are managed in the fork's repository.

        """)
        for (label, url) in [("Fork repository", repository), ("Releases", releases),
                             ("Report an issue", issues), ("Contribute", contributing),
                             ("Original MacGames project", upstream)] {
            credits.append(NSAttributedString(string: label, attributes: [.link: url]))
            credits.append(NSAttributedString(string: "\n"))
        }
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: name,
            .credits: credits,
        ])
    }
}
