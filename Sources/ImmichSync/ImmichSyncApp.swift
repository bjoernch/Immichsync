import AppKit
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
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = image
        }
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
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarLabelView: View {
    @EnvironmentObject private var folderStore: BackupFolderStore

    var body: some View {
        let state = syncState()
        return Image(systemName: state.symbol)
            .foregroundStyle(state.color)
    }

    private func syncState() -> (symbol: String, color: Color) {
        if folderStore.isDownloading {
            return ("arrow.down", .blue)
        }
        if folderStore.isUploadTransferring {
            return ("arrow.up", .orange)
        }
        return ("circle", .secondary)
    }

    
}
