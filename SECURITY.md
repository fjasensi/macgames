# MacGames Fork security policy

This policy applies to [fjasensi/macgames](https://github.com/fjasensi/macgames), an independent
fork of MacGames maintained by [fjasensi](https://github.com/fjasensi).

## Reporting a problem

Please do not post vulnerability details in a public issue. If this repository's **Security**
tab offers **Report a vulnerability**, use it. Otherwise, ask the fork maintainer through a
[new issue](https://github.com/fjasensi/macgames/issues/new/choose) for a private reporting
channel, without including exploit steps, credentials or other sensitive details.

## What counts

MacGames starts Windows programs, downloads files and runs helpers, so these matter most:

- A way to run code through `MacGamesBridge` or the x87sidecar launch path that a game would not run
  anyway
- A way around the SHA-256 checks on downloads
- A way for the Windows environment to reach files outside its own folder that it should not reach
- Anything that changes files outside `~/Library/Application Support/macgames` and the app itself

Problems in Wine, Steam, DXMT, x87sidecar or a game itself belong to those projects. If you are not
sure, report it here and we will help pass it on.
