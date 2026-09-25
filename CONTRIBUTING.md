# Contributing

Thanks for taking a look. Issues and pull requests are welcome; small,
focused changes are easiest to review.

## Before you start

- Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). It explains the layers
  and what the app deliberately does *not* do (no backend of its own, and no
  dependencies beyond the two OAuth/JWT libraries).
- For anything beyond a bug fix, open an issue first so we can agree on the
  shape of the change before you spend time on it.

## Style

- Readable and conventional Swift. Prefer the obvious SwiftUI or Foundation
  way of doing something over a clever one.
- Use standard iOS controls and Apple's design language. The app's one
  brand touch is its accent colour (`AccentColor` in the asset catalogue).
- No new third-party dependencies without discussion. OAuth and DPoP come
  from [OAuthenticator](https://github.com/ATProtoKit/OAuthenticator) and
  [Jot](https://github.com/ATProtoKit/Jot) precisely so that we don't
  maintain security-sensitive code ourselves; everything else is in-tree.
- Tests define intent. Write them as statements of behaviour ("a removed
  activity is not synced again automatically"), not as assertions about
  byte layouts. A change in behaviour should come with the test that
  describes it.
- Error messages shown to the user must make sense to a person.
- British English in docs and UI copy.

## Running the tests

All unit tests live in the `KimbiaKit` package and run on macOS without Xcode
project generation:

```sh
make test
# or: swift test --package-path Packages/KimbiaKit --parallel
```

To build the app itself, see "Building locally" in the [README](README.md).
CI runs both on every push.

## Commits and pull requests

- One logical change per pull request.
- Explain *why* in the description; the diff already shows *what*.
- CI must be green.
- If the change is one a user of the app would notice, describe it in a change
  file (below).

## Change files

A pull request that changes what someone using the app would notice adds a
file to `.changeset/`. Write one with `knope document-change`, or by hand as
`.changeset/anything.md`:

```markdown
---
default: minor
---

Walks can now be kept out of Kimbia while runs still sync.
```

`default` is this repo's one package. The level is `major`, `minor` or
`patch`; while the version is below 1.0 these shift down one, so a `minor`
change bumps the patch number. Write the text as a changelog entry — for
someone deciding whether to update, not for a reviewer reading the diff.

A pull request that changes nothing a user would notice (CI, tests, internal
refactoring) needs no file.

Merging to `main` opens a release pull request collecting these entries; see
[docs/RELEASING.md](docs/RELEASING.md).
