# Architecture

Kimbia Sync is one iOS app target over one Swift package. There is no
server of its own: everything happens between the phone, Apple Health and
the person's PDS.

```
Apple Health ──▶ HealthKitWorkoutSource ──▶ SyncEngine ──▶ KimbiaActivityMapper ──▶ PDSClient ──▶ PDS
                  (app)                     (KimbiaKit)    (KimbiaKit)              (KimbiaKit)
```

## KimbiaKit (`Packages/KimbiaKit`)

Everything that can be tested without a phone. `swift test` runs it on macOS.

| Folder | What's in it |
| --- | --- |
| `ATProto/` | Identity resolution, OAuth sign-in (PAR, PKCE and DPoP via [OAuthenticator](https://github.com/ATProtoKit/OAuthenticator) and [Jot](https://github.com/ATProtoKit/Jot)), and `PDSClient` for XRPC calls, which refreshes tokens transparently and writes them back to the Keychain. Shared with [semble-share-sheet](https://github.com/jphastings/semble-share-sheet). |
| `Session/` | The signed-in `Session` and its Keychain store. The item is readable after first unlock, because background syncs can run while the phone is locked. |
| `Sync/` | `Workout`, `ActivityFilter`, the on-device `SyncLedger`, and `SyncEngine`, which decides what to upload and does it. |
| `Kimbia/` | `KimbiaActivityMapper`, the only code that knows Kimbia's `app.kimbia.activity` lexicon; `KimbiaPrivacy`; and `Polyline`, which encodes, crops and simplifies routes. |

### Deciding what syncs

- `ActivityFilter` holds an explicit on/off for each type the person has
  chosen for, plus one `includeOthers` switch (off by default) for every
  other type. On first setup, every type they have done is given an
  explicit choice, so "others" only ever means types they haven't done or
  haven't looked at.
- `SyncLedger.autoSyncFrom` is set when setup finishes. Workouts ending
  after it are synced automatically if the filter includes them; workouts
  before it are only ever synced by ticking them on the import screen.
- `SyncLedger.synced` records what was written (and where), so nothing is
  uploaded twice and the app can list and delete its records.
  `SyncLedger.removed` records what the person deleted, so automatic sync
  doesn't put it back.
- Record keys are `TID.stable(date: workout.start, discriminator: workout.id)`,
  and records are written with `putRecord`. If the ledger is lost, a re-sync
  overwrites each record with itself instead of duplicating it.

### Failures

`SyncEngine` tells apart failures that belong to one activity (the PDS
rejected that record, or the mapper can't represent it), which are reported
and skipped, from ones that would fail every activity (offline, signed out,
rate-limited, the PDS down), which stop the sync so it is retried next
time. Progress is saved after every record, so a sync that iOS cuts short
resumes where it stopped. Calls are serialised, so a background wake-up
never races a sync started from the UI.

### Mapping to Kimbia

Every HealthKit type maps to one of Kimbia's `sportType`s: running → `run`,
cycling → `ride`, swimming → `swim`, walking → `walk`, hiking → `hike`, and
anything else → `other`. Decimals are strings and durations whole seconds,
as the lexicon requires. `source` is `apple-health`.

The lexicon describes how Kimbia protects what it publishes, and the app
does the same, controlled by `KimbiaPrivacy`:

- `startedAt` is the local day at noon UTC unless exact times are shared,
  in which case it is the true start with its local offset, and
  `elapsedTime` is added.
- `polyline` is omitted, cropped (500 m trimmed from each end) or full.
  Long routes are simplified (Ramer–Douglas–Peucker) to fit the lexicon's
  20 000 characters, and `altitude` has one value per kept point.

## The app (`KimbiaSync/`)

| File | Role |
| --- | --- |
| `KimbiaSyncApp.swift` | Entry point. The app delegate registers background work at every launch, since HealthKit and BackgroundTasks require it. |
| `AppEnvironment.swift` | Identifiers, OAuth configuration and shared stores. |
| `Health/` | Reading workouts from HealthKit, and names and symbols for activity types. |
| `Sync/SyncRunner.swift` | One `SyncEngine` per account, shared by the UI and background triggers. |
| `Sync/BackgroundSync.swift` | HealthKit observer query with background delivery (the main trigger) and a `BGAppRefreshTask` safety net. |
| `Sync/SyncModel.swift` | Observable state for the signed-in screens. |
| `Views/` | Sign-in, Health permission, activity choices, import, home, settings and removal screens, all standard SwiftUI. |

## What the app contacts

- **At sign-in:** `public.api.bsky.app` and `plc.directory` (or the
  handle's own domain, or a `did:web` host) to find the PDS, then the PDS's
  authorisation server.
- **Afterwards:** only the PDS, and its authorisation server to refresh
  tokens. On many PDSs, including Bluesky's, the authorisation server is a
  separate host (the "entryway"), which OAuth requires the app to use.
