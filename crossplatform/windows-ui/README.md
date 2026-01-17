# Windows UI (Tauri)

This directory contains a Tauri-based Windows interface that mirrors the existing macOS sections while still relying on the shared Swift backend for the sync logic.

## Structure
- `src` is a React + Vite UI that renders the sidebar, dashboard, and every configuration section (download/upload, history, connection, etc.).
- `src-tauri` hosts the Tauri Rust bridge with lightweight commands such as `fetch_dashboard`, `sync_now`, and `validate_connection`. Those commands currently return fixture data but are the place to connect to the Swift backend (see below).

## Running
1. Install dependencies:
   ```bash
   cd crossplatform/windows-ui
   npm install
   ```
2. Launch the UI and Tauri dev server:
   ```bash
   npm run tauri dev
   ```
3. Build production artifacts:
   ```bash
   npm run tauri build
   ```
   The resulting `.msi`/`.exe` will live under `crossplatform/windows-ui/src-tauri/target/release/bundle`.

## Backend integration
To reuse the Swift backend you already build via `./crossplatform/build.sh`, update the command handlers in `src-tauri/src/main.rs`:

1. Replace the stubbed responses with `std::process::Command` invocations that run `dist/windows/ImmichSync.exe` (or a dedicated CLI compiled from the Swift shared core).
2. Stream data back to the frontend by printing JSON that the Rust bridge parses, or add a simple IPC layer (HTTP/gRPC) for status updates.
3. Share the same CLI/interface with the macOS SwiftUI app so backend changes stay synchronized.

This UI can be iterated independently while the Swift backend remains the ultimate source of truth for sync logic.

## Tray & mini app

Tauri now creates a system tray item (bottom-right on Windows) that keeps ImmichSync running in the background. Left- or right-clicking the tray icon shows the mini window with condensed status, the same “Sync Now” action, and buttons to open the full dashboard or hide the mini view. The tray context menu also exposes “Open ImmichSync”, “Show Mini App”, “Sync now”, and “Quit ImmichSync”.

The mini window is backed by `src/mini.tsx` and `src/MiniApp.tsx`. When the tray menu or mini buttons call `Sync now`, the Rust bridge still delegates to `src-tauri/src/main.rs -> sync_now`, which is the ideal place to invoke the shared Swift backend executable under `dist/windows/ImmichSync.exe`.
