# Cross-platform build

This directory organizes the shared Swift backend so you can build ImmichSync for both macOS and Windows without duplicating business logic.

## Approach
1. Use the existing Swift sources in `Sources/ImmichSync` as a reusable backend that already handles downloads, uploads, and syncing logic.
2. Run `./scripts/build-app.sh` for the current macOS GUI experience, which packages the app bundle as usual.
3. Build a Windows-friendly CLI by invoking the Swift compiler with a Windows triple, producing `dist/windows/ImmichSync.exe` from the same codebase.

## Scripts
- `build.sh`: runs the macOS app build (via `scripts/build-app.sh`) and then produces the Windows binary in `dist/windows/`.
- `build-windows.sh [TRIPLE]`: cross-compiles the Swift target for the provided Windows triple (default `x86_64-unknown-windows-msvc`) and copies the resulting `.exe` into `dist/windows/`.

## Requirements
- macOS: Xcode 15+ / the Swift toolchain that the project already targets (13+ only uses Foundation-style APIs in the backend, so cross-compilation is possible).
- Windows cross-compilation: download and install the Windows Swift toolchain and make sure `swift` can build for `x86_64-unknown-windows-msvc` (or another supported triple). The scripts expect that the toolchain is visible to the current `swift` executable.

## How to use
1. From the repository root, run `./crossplatform/build.sh`. That produces the default macOS `.app` bundle in `dist/` plus a Windows `ImmichSync.exe` under `dist/windows/`.
2. Use familiar packaging/installer tooling (e.g., WiX or a self-contained archive) if you need a Windows installer.
3. Repeat the Windows build with custom triples (e.g., `./crossplatform/build-windows.sh x86_64-pc-windows-msvc`) when targeting different Windows toolchains.
