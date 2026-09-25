# Design assets

## `icon.svg`

A placeholder app icon: a running track that loops round into a sync
arrow, on a warm orange. Swap in something closer to Kimbia's own look
when there is one.

## Rendered icons

`render-icon.cjs` renders `icon.svg` to:

| File | Size | Used for |
| --- | --- | --- |
| `KimbiaSync/Assets.xcassets/AppIcon.appiconset/icon-1024.png` | 1024 × 1024 | App icon (Xcode derives every other size) |
| `web/icon.png` | 512 × 512 | `logo_uri` in the OAuth client metadata and the landing page |

Both are 8-bit RGB PNGs with **no alpha channel**: App Store Connect rejects
app icons that carry one, even when every pixel is opaque.

To regenerate (needs Node 22+; the renderer is installed into a throwaway
directory so nothing is added to the repo):

```sh
make icon
```
