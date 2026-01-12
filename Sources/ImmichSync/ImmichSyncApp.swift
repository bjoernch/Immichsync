import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppTerminationController.shared.allowTerminate {
            return .terminateNow
        }
        sender.hide(nil)
        return .terminateCancel
    }
}

@main
struct ImmichSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var folderStore: BackupFolderStore

    init() {
        let store = BackupFolderStore()
        _folderStore = StateObject(wrappedValue: store)
        if CommandLine.arguments.contains("--sync-now") {
            DispatchQueue.main.async {
                store.startDownloadAllAssets()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(folderStore)
        }
        .windowStyle(.automatic)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(folderStore)
        } label: {
            MenuBarLabelView()
                .environmentObject(folderStore)
        }
    }
}

struct MenuBarLabelView: View {
    @EnvironmentObject private var folderStore: BackupFolderStore

    var body: some View {
        let state = syncState()
        return HStack(spacing: 6) {
            menuIcon()
                .renderingMode(.template)
                .foregroundStyle(state.color)
            Text("ImmichSync")
        }
    }

    private func syncState() -> (symbol: String, color: Color) {
        if folderStore.isDownloading {
            return ("arrow.down.circle.fill", .blue)
        }
        if folderStore.isUploading {
            return ("arrow.up.circle.fill", .orange)
        }
        return ("circle.dotted", .secondary)
    }

    private func menuIcon() -> Image {
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return Image(nsImage: image)
        }
        return Image(systemName: "circle.dotted")
    }
}
