# Setup

One-time setup for a maintainer or for a fork. You only need this if you
want to run the app on a real device, publish your own client metadata, or
ship to TestFlight; building for the Simulator needs nothing here.

## 1. Bundle identifier and team

Everything is generated from `project.yml`. Change the bundle id
(`me.byjp.KimbiaSync`) and set `DEVELOPMENT_TEAM` to your Team ID, then run
`xcodegen generate`.

## 2. OAuth client metadata and GitHub Pages

ATProto OAuth identifies a client by a URL that serves its metadata
document, so the metadata has to be live before anyone can sign in.
`web/` is published to GitHub Pages by `.github/workflows/pages.yml` and
served from the custom domain `kimbia-sync.byjp.me`.

1. In the repository settings, under **Pages**, set **Source** to
   **GitHub Actions** (not "Deploy from a branch"). The workflow fails
   until this is done.
2. At the DNS provider, add a `CNAME` record pointing `kimbia-sync.byjp.me`
   at `jphastings.github.io`. The `web/CNAME` file tells Pages which domain
   to serve; once DNS has propagated, tick **Enforce HTTPS** in the Pages
   settings (a client_id must be `https`).
3. Push to `main` (or run the workflow by hand). Check that
   `https://kimbia-sync.byjp.me/oauth-client-metadata.json` returns the JSON.

See GitHub's guide to
[managing a custom domain for GitHub Pages](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site).

For a fork, edit `web/CNAME` and `web/oauth-client-metadata.json`:

- `client_id`, `client_uri`, `logo_uri`, `policy_uri` become your URLs.
- **The redirect scheme is derived from the `client_id` host.** The
  [ATProto OAuth spec](https://atproto.com/specs/oauth#clients) requires a
  native client's custom-scheme redirect URI to be the reverse-DNS form of
  the client_id's domain: `kimbia-sync.byjp.me` → `me.byjp.kimbia-sync`, so
  the redirect URI is `me.byjp.kimbia-sync:/oauth/callback` (note the single
  slash). Change `redirect_uris` here *and* the URL scheme in `project.yml`,
  plus `KimbiaSync/AppEnvironment.swift`.

`scope` must match `AppEnvironment.oauthScope`.

## 3. Apple Developer

In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list):

1. Register an explicit **App ID** for `me.byjp.KimbiaSync` and enable the
   **HealthKit** capability, ticking **Background Delivery**. Background
   delivery is what lets HealthKit wake the app when a workout is saved; see
   Apple's
   [`com.apple.developer.healthkit.background-delivery`](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit.background-delivery).
2. In [App Store Connect](https://appstoreconnect.apple.com), create the app
   record with that bundle id. TestFlight distribution needs nothing more
   than an uploaded build; see [RELEASING.md](RELEASING.md) for the
   certificate, profile and API key the release workflow uses.

Local device builds work with automatic signing in Xcode once the App ID
exists; the manual-signing setup is only for CI.

HealthKit apps must have a privacy policy; `web/privacy.html` is it, and
its URL goes in App Store Connect under **App Privacy**.
