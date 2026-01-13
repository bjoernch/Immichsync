<div align="center">
  <img src="assets/logo.png" width="140" height="140" alt="ImmichSync logo" />
  <h1>ImmichSync</h1>
  <p>Fast, local-first backup and upload companion for your Immich server on macOS.</p>

  <p>
    <a href="#readme">README</a> ·
    <a href="#contributing">Contributing</a> ·
    <a href="#license">MIT License</a>
  </p>

  <p>
    <img alt="License" src="https://img.shields.io/badge/License-MIT-84cc16" />
    <img alt="macOS" src="https://img.shields.io/badge/macOS-12.0%2B-3b82f6" />
  </p>

  <p>
    <a href="https://github.com/bjoernch/Immichsync/releases/latest">Download</a>
    &nbsp;·&nbsp;
    <a href="https://github.com/bjoernch/Immichsync/releases">Latest Release</a>
  </p>
</div>

---

## README

ImmichSync keeps a local copy of your Immich assets, and can watch a folder to upload new files back to your server. It’s designed for fast, reliable syncing with clear status and safety controls.

<p align="center">
  <img src="assets/app-screenshot.png" alt="ImmichSync app screenshot" width="900" />
</p>

## Install (unsigned build)

1) Download `ImmichSync.dmg` or `ImmichSync.zip` from GitHub Releases.  
2) Open the DMG/ZIP and drag `ImmichSync.app` to `/Applications`.  
3) If macOS blocks it, right‑click the app → **Open**, or allow it in System Settings → Privacy & Security.

## Manual dev build

```bash
swift run
```

## Build a clickable app

```bash
./scripts/build-app.sh
```

The app bundle will be at `dist/ImmichSync.app`.

## How it works and configuration

### Core features
- Download assets with filters (photos/videos), optional album filter, and folder structure rules.
- Upload watcher for a local folder (with queue + live sync).
- Scheduling and background launch agent support.
- Menu bar status with sync controls.

### Immich API permissions (minimum)
Grant only what you use. Recommended minimal set:
- `asset.read` (list/search assets, read metadata)
- `asset.download` (download originals)
- `asset.upload` (upload files)
- `album.read` (only if you use album filtering)
- `duplicate.read` (only if you use the duplicates view)
- `server.about` (or equivalent server info permission for version display)

If you disable uploads, you can drop `asset.upload`. If you disable duplicates, drop `duplicate.read`. If you disable album filtering, drop `album.read`.

### Credentials and security
- API key is saved locally only when you click **Save API Key**.
- Keychain storage is available only when Touch ID is enabled.
- Touch ID gating is optional and protects access to the app UI.

### Storage locations
- Preferences: `UserDefaults`
- App data: `~/Library/Application Support/ImmichSync`
- Keychain entry: service name `ImmichSync` (if enabled)

### Release packaging (unsigned)

```bash
./scripts/package-release.sh
```

Creates `dist/ImmichSync.zip` and `dist/ImmichSync.dmg`.

### GitHub Releases (automatic)

Push a tag like `v0.1.0` and GitHub Actions will build and attach the ZIP/DMG to a published release.

```bash
git tag v0.1.0
git push origin v0.1.0
```

## Contributing

Issues and pull requests are welcome. If you plan a larger change, please open an issue first so we can align on scope and behavior.

## License

MIT License.
