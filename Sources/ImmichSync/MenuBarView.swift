import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var folderStore: BackupFolderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ImmichSync")
                .font(.headline)

            if folderStore.isDownloading {
                Text(folderStore.progressText.isEmpty ? "Downloading..." : folderStore.progressText)
                    .font(.caption)
            } else if folderStore.isUploading {
                Text(folderStore.uploadProgressText.isEmpty ? "Uploading..." : folderStore.uploadProgressText)
                    .font(.caption)
            } else if let lastSync = folderStore.lastSyncDate {
                Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
            } else {
                Text("Idle")
                    .font(.caption)
            }

            if !folderStore.speedText.isEmpty {
                Text(folderStore.speedText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !folderStore.uploadSpeedText.isEmpty {
                Text(folderStore.uploadSpeedText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Sync Now") {
                folderStore.startDownloadAllAssets()
            }
            .disabled(folderStore.isDownloading)

            Button("Upload Now") {
                folderStore.startUploadNow()
            }
            .disabled(folderStore.isUploading)

            Button("Stop Sync") {
                folderStore.stopDownload()
            }
            .disabled(!folderStore.isDownloading)

            Button("Stop Upload") {
                folderStore.stopUpload()
            }
            .disabled(!folderStore.isUploading)

            Button("Open App") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }

            Divider()

            Button("Exit") {
                AppTerminationController.shared.allowTerminate = true
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(minWidth: 240)
    }
}
