# MacGames Fork website

The fork's landing page is published at <https://fjasensi.github.io/macgames/>.
It is a standalone HTML/CSS page, separate from the original website archived in `docs/`.
Screenshots come from `docs/images/`. No package manager, analytics or external fonts are needed.

Build locally with `scripts/build-pages.sh`; the output is `build/pages/`.
Preview with `python3 -m http.server 8080 --directory build/pages`.

To publish changes, sign in to GitHub CLI as the fork maintainer and run:

```sh
scripts/publish-pages.sh
```

The script commits only the assembled website to the `gh-pages` branch. GitHub Pages serves
the branch root. It does not merge or change the app's `main` branch. Commit website source
changes in the usual app pull request as well.
Website commits use the active GitHub account's public username and GitHub noreply email.

GitHub Pages is configured once with `gh-pages` as its source, without a custom domain.
