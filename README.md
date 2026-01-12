# ImmichSync

macOS app to sync Immich assets to a local folder and optionally upload new files to your server.

## Features

- Download assets with filters, folder structure, and optional sidecar metadata
- Upload watcher with queue and live sync
- Scheduling, background launch agent, and menu bar status
- Touch ID gated access (optional)

## Run (dev)

```bash
swift run
```

## Build a clickable app

```bash
./scripts/build-app.sh
```

The app bundle will be at `dist/ImmichSync.app`. You can drag it into `/Applications`.

## Package release assets (unsigned)

```bash
./scripts/package-release.sh
```

This creates `dist/ImmichSync.zip` and `dist/ImmichSync.dmg`.

## Installing unsigned builds

Unsigned apps will trigger Gatekeeper. Users can right‑click the app and choose **Open**, or use System Settings → Privacy & Security to allow it. For a warning‑free experience, the app must be signed and notarized.

## Notes

- The app stores security‑scoped bookmarks for folder access across launches.
- API keys can be stored in Keychain only when Touch ID is enabled and the user saves them.
- Downloaded and uploaded asset IDs are tracked to enable incremental sync.
