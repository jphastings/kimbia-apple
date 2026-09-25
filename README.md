# Kimbia Sync

An iOS app that sends the workouts you record in Apple Health to
[Kimbia](https://kimbia.app), the AT Protocol training journal. Choose which
kinds of activity sync (runs but not walks, say), import as much of your
history as you like, and from then on each new workout is added to Kimbia as
soon as it's saved to Health, even when the app isn't open.

It talks to the AT Protocol directly: you sign in with your atmosphere
account and the app writes Kimbia's record types to your own repository.
There is no middle-man server.

This is an independent, unofficial app, not made by Kimbia.

> **Status:** the sign-in, Health, filtering, import and background-sync
> machinery is in place. Writing records is switched off until the mapping
> to Kimbia's lexicon (`KimbiaActivityMapper`) is written.

## How it works

- You sign in once with [ATProto OAuth](https://atproto.com/specs/oauth).
  The app never sees a password; DPoP-bound tokens live in the iOS Keychain
  and are refreshed with your PDS's authorisation server as needed, in the
  background too.
- **What syncs.** Every kind of activity you've done in Health gets its own
  switch. One "Other Activities" switch, off by default, covers everything
  else, including sports you haven't tried yet. You can add a type in
  advance to allow it, or keep it out, before your first workout of that kind.
- **Importing history.** Past workouts are listed with a tick each. The ones
  matching your choices start ticked, so you can see what your choices mean
  for your data; select all, none, or pick by hand.
- **Background sync.** HealthKit
  [background delivery](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:))
  wakes the app when a workout is saved, with a
  [background app refresh](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask)
  task as a safety net.
- **Removing.** Switching a type off only affects future workouts; the app
  says so and offers to delete the ones already synced. Any synced activity
  can be removed from your PDS from Settings, and won't be re-synced unless
  you import it again.
- Each workout's record key is derived from the workout itself, so syncing
  one twice (after a reinstall, say) overwrites it rather than adding a
  duplicate.

After sign-in the app talks only to your PDS and its authorisation server.
Signing in also looks your handle up in the public directory; the
[privacy notice](https://kimbia-sync.byjp.me/privacy.html) lists every host
the app contacts.

Details are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Install

TestFlight: _link coming soon_.

## Building locally

You need Xcode 16.3 or newer (the OAuth library uses Swift 6.1 syntax) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate           # or: make generate
open KimbiaSync.xcodeproj   # or: make open
```

The `.xcodeproj` is generated from `project.yml` and is not committed.
HealthKit doesn't work in the Simulator's background, and needs a signed
build with the HealthKit capability on a device; [docs/SETUP.md](docs/SETUP.md)
explains what to set up.

All unit tests are in the `KimbiaKit` package and run without Xcode:

```sh
make test   # swift test --package-path Packages/KimbiaKit
```

## Project layout

```
KimbiaSync/           The app: sign-in, Health, activity choices, import, background sync
Packages/KimbiaKit/   ATProto OAuth and XRPC, the sync engine, Kimbia's records, and all tests
web/                  GitHub Pages site: OAuth client metadata, landing page, privacy notice
Design/               Icon source and renderer
fastlane/             `test` and `beta` (TestFlight) lanes
.github/workflows/    ci.yml (build + test), release.yml (TestFlight), pages.yml (website)
docs/                 ARCHITECTURE, SETUP, RELEASING
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Maintainer docs:
[docs/SETUP.md](docs/SETUP.md) (one-time setup for a fork) and
[docs/RELEASING.md](docs/RELEASING.md) (shipping to TestFlight).

The ATProto sign-in and PDS code started life in
[semble-share-sheet](https://github.com/jphastings/semble-share-sheet).

## Licence

[MIT](LICENSE) © 2026 JP Hastings-Spital.
