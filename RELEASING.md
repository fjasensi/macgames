# Releasing MacGames Fork

Fork releases are published in [fjasensi/macgames](https://github.com/fjasensi/macgames/releases).
They are independent of the original MacGames releases. The fork uses manual updates and has
no automatic update feed; it does not use the upstream Sparkle feed or signing key.

For a local build, use `scripts/build-fork.sh` as described in
[CONTRIBUTING.md](CONTRIBUTING.md#using-the-fork-as-your-daily-app).
Publishing a notarized release requires the maintainer's own Apple signing credentials.

## One-time setup

1. **Developer ID.** Install a "Developer ID Application" certificate in your login keychain.
   The script uses the first one it finds, or the one named in `DEVELOPER_ID`.
2. **Notarization.** Store App Store Connect credentials as a notarytool keychain profile:

   ```sh
   xcrun notarytool store-credentials <profile name> --team-id <your team ID>
   ```

   Pass the profile name as `NOTARY_PROFILE` when you release.
3. **GitHub.** Sign in with `gh auth login`, with push rights to `fjasensi/macgames`.
   Confirm that `origin` points to the fork before publishing a tag.

## Each release

1. Set `MARKETING_VERSION` and raise `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Add a `## <version> - <date>` section to `CHANGELOG.md`, and commit both.
3. Run:

   ```sh
   NOTARY_PROFILE=<profile name> scripts/release.sh <version>
   ```

The script builds `MacGames Fork.app`, signs it with the maintainer's Developer ID and the
hardened runtime, notarizes the app and disk image, and publishes `MacGames-Fork-<version>.dmg`
and a ZIP archive to the fork's GitHub release. Users install updates by replacing the app;
Steam, installed games and local library preferences remain in their existing data folders.

## Runtime and licensing

- The app still downloads the pinned upstream runtime and game packs. Their signatures,
  source archives, hashes and licenses stay intact.
- The Wine runtime and the packs keep the signatures they ship with. The script never re-signs
  them: Wine's entitlements must stay as they are.
- `MacGamesBridge` needs `App/MacGamesBridge.entitlements`. Without it, the hardened runtime
  removes the `DYLD_` variables that Wine needs before the bridge hands them on to x87sidecar.
- Preserve the original MacGames copyright, [LICENSE](LICENSE) and
  [third-party notices](THIRD_PARTY_NOTICES.md) in every release.
