import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var folderStore: BackupFolderStore
    @State private var apiKeyDraft = ""
    @State private var selectedSection: AppSection = .download
    @State private var onboardingStep: OnboardingStep = .credentials

    var body: some View {
        Group {
            if !folderStore.isUnlocked {
                lockView
            } else if !hasCredentials {
                onboardingView
            } else {
                mainView
            }
        }
        .frame(minWidth: 720, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if apiKeyDraft.isEmpty {
                apiKeyDraft = folderStore.apiKey
            }
            folderStore.ensureUnlockState()
            folderStore.refreshAlbums()
            folderStore.refreshServerInfo()
            folderStore.refreshDuplicates()
        }
    }

    private var hasCredentials: Bool {
        !folderStore.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !folderStore.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var mainView: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            Section("Core") {
                Label("Download", systemImage: "arrow.down.circle").tag(AppSection.download)
                Label("Upload", systemImage: "arrow.up.circle").tag(AppSection.upload)
            }
            Section("Settings") {
                Label("Connection", systemImage: "key.horizontal").tag(AppSection.connection)
                Label("Schedule", systemImage: "calendar").tag(AppSection.schedule)
                Label("Background", systemImage: "bolt.badge.clock").tag(AppSection.background)
            }
            Section("Insights") {
                Label("Server", systemImage: "server.rack").tag(AppSection.server)
                Label("Duplicates", systemImage: "square.on.square").tag(AppSection.duplicates)
            }
            Section("System") {
                Label("Reset", systemImage: "arrow.counterclockwise").tag(AppSection.reset)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ImmichSync")
    }

    private var detailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                switch selectedSection {
                case .download:
                    downloadSection
                case .upload:
                    uploadSection
                case .connection:
                    connectionSection
                case .schedule:
                    scheduleSection
                case .background:
                    backgroundSection
                case .server:
                    serverSection
                case .duplicates:
                    duplicatesSection
                case .reset:
                    resetSection
                }

                footer
            }
            .padding(28)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            LogoView(size: 52)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 6) {
                Text("ImmichSync")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                Text("Control downloads, uploads, and sync rules from one place.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                statusPill
                if !folderStore.serverVersion.isEmpty {
                    Text("Server \(folderStore.serverVersion)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusPill: some View {
        let label: String
        let color: Color
        if folderStore.isDownloading {
            label = "Syncing"
            color = .blue
        } else if folderStore.isUploading {
            label = "Uploading"
            color = .orange
        } else {
            label = "Ready"
            color = .green
        }
        return Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var connectionSection: some View {
        SectionCard(title: "Connection", subtitle: "Manage credentials and security.") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Server URL (https://immich.example.com)", text: Binding(
                    get: { folderStore.serverURL },
                    set: { folderStore.updateServerURL($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

                SecureField("API key", text: $apiKeyDraft)
                    .textFieldStyle(.roundedBorder)

                Toggle("Require Touch ID on launch", isOn: Binding(
                    get: { folderStore.requireTouchID },
                    set: { folderStore.updateRequireTouchID($0) }
                ))

                Toggle("Store API key in Keychain", isOn: Binding(
                    get: { folderStore.useKeychain },
                    set: { folderStore.updateUseKeychain($0) }
                ))
                .disabled(!folderStore.requireTouchID)

                HStack {
                    if !folderStore.requireTouchID {
                        Text("Enable Touch ID to store API key in Keychain.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Save API Key") {
                        folderStore.updateApiKey(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .disabled(!isCredentialDraftValid)
                }
            }
        }
    }

    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Download Folder", subtitle: "Where your Immich assets will be stored locally.") {
                VStack(alignment: .leading, spacing: 12) {
                    if let url = folderStore.selectedURL {
                        Text(url.path)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            Spacer()
                            Button("Open in Finder") {
                                folderStore.revealInFinder()
                            }

                            Button("Change Folder") {
                                folderStore.chooseFolder()
                            }

                            Button("Clear") {
                                folderStore.clearSelection()
                            }
                            .tint(.red)
                        }
                    } else {
                        Text("No folder selected yet.")
                            .foregroundStyle(.secondary)

                        HStack {
                            Spacer()
                            Button("Choose Folder") {
                                folderStore.chooseFolder()
                            }
                        }
                    }
                }
            }

            SectionCard(title: "Download Filters", subtitle: "Choose what to sync.") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Toggle("Photos", isOn: Binding(
                            get: { folderStore.includePhotos },
                            set: { folderStore.updateIncludePhotos($0) }
                        ))
                        Toggle("Videos", isOn: Binding(
                            get: { folderStore.includeVideos },
                            set: { folderStore.updateIncludeVideos($0) }
                        ))
                        Spacer()
                    }

                    Toggle("Skip trashed assets", isOn: Binding(
                        get: { folderStore.skipTrashed },
                        set: { folderStore.updateSkipTrashed($0) }
                    ))

                    HStack(spacing: 12) {
                        Text("Album")
                            .frame(width: 60, alignment: .leading)

                        Picker("Album", selection: Binding(
                            get: { folderStore.selectedAlbumID },
                            set: { folderStore.updateSelectedAlbumID($0) }
                        )) {
                            Text("All assets").tag("")
                            ForEach(folderStore.albums) { album in
                                Text("\(album.name) (\(album.assetCount))").tag(album.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Refresh") {
                            folderStore.refreshAlbums()
                        }
                    }

                    HStack(spacing: 12) {
                        Text("Folders")
                            .frame(width: 60, alignment: .leading)

                        Picker("Folder structure", selection: Binding(
                            get: { folderStore.downloadFolderStructure },
                            set: { folderStore.updateDownloadFolderStructure($0) }
                        )) {
                            Text("Flat").tag("flat")
                            Text("Year").tag("year")
                            Text("Year / Month").tag("year-month")
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Toggle("Write sidecar metadata JSON", isOn: Binding(
                        get: { folderStore.writeSidecarMetadata },
                        set: { folderStore.updateWriteSidecarMetadata($0) }
                    ))
                }
            }

            SectionCard(title: "Sync", subtitle: "Download and track your assets.") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Spacer()
                        Button(folderStore.isDownloading ? "Syncing..." : "Sync Now") {
                            folderStore.startDownloadAllAssets()
                        }
                        .disabled(folderStore.isDownloading)

                        Button("Stop") {
                            folderStore.stopDownload()
                        }
                        .disabled(!folderStore.isDownloading)
                    }

                    if !folderStore.progressText.isEmpty {
                        Text(folderStore.progressText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !folderStore.speedText.isEmpty {
                        Text(folderStore.speedText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !folderStore.downloadSpeedSamples.isEmpty {
                        SpeedGraphView(samples: folderStore.downloadSpeedSamples, color: .blue)
                    }

                    if let lastSync = folderStore.lastSyncDate {
                        Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let error = folderStore.lastError, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var uploadSection: some View {
        SectionCard(title: "Upload Watcher", subtitle: "Upload new files from a local folder.") {
            VStack(alignment: .leading, spacing: 12) {
                if let url = folderStore.uploadFolderURL {
                    Text(url.path)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(2)
                } else {
                    Text("No upload folder selected yet.")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Spacer()
                    Button("Choose Folder") {
                        folderStore.chooseUploadFolder()
                    }

                    Button("Clear") {
                        folderStore.clearUploadSelection()
                    }
                    .tint(.red)
                }

                Toggle("Monitor folder for new files", isOn: Binding(
                    get: { folderStore.uploadEnabled },
                    set: { folderStore.updateUploadEnabled($0) }
                ))

                Toggle("Include subfolders", isOn: Binding(
                    get: { folderStore.includeUploadSubfolders },
                    set: { folderStore.updateIncludeUploadSubfolders($0) }
                ))

                HStack(spacing: 16) {
                    Toggle("Upload photos", isOn: Binding(
                        get: { folderStore.uploadIncludePhotos },
                        set: { folderStore.updateUploadIncludePhotos($0) }
                    ))
                    Toggle("Upload videos", isOn: Binding(
                        get: { folderStore.uploadIncludeVideos },
                        set: { folderStore.updateUploadIncludeVideos($0) }
                    ))
                    Spacer()
                }

                HStack(spacing: 12) {
                    Spacer()
                    Button(folderStore.isUploading ? "Uploading..." : "Upload Now") {
                        folderStore.startUploadNow()
                    }
                    .disabled(folderStore.isUploading)

                    Button("Stop") {
                        folderStore.stopUpload()
                    }
                    .disabled(!folderStore.isUploading)
                }

                if !folderStore.uploadProgressText.isEmpty {
                    Text(folderStore.uploadProgressText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !folderStore.uploadSpeedText.isEmpty {
                    Text(folderStore.uploadSpeedText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !folderStore.uploadSpeedSamples.isEmpty {
                    SpeedGraphView(samples: folderStore.uploadSpeedSamples, color: .orange)
                }

                Text("Uploads keep file creation and modification timestamps for timeline accuracy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !folderStore.uploadQueue.isEmpty {
                    Divider()
                    Text("Upload queue")
                        .font(.footnote.weight(.semibold))

                    ForEach(folderStore.uploadQueue.prefix(8)) { item in
                        HStack {
                            Text(URL(fileURLWithPath: item.path).lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(item.status.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var scheduleSection: some View {
        SectionCard(title: "Schedule", subtitle: "Run an automatic sync daily.") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable daily sync", isOn: Binding(
                    get: { folderStore.scheduleEnabled },
                    set: { folderStore.updateScheduleEnabled($0) }
                ))

                HStack(spacing: 12) {
                    Text("Time")
                        .frame(width: 60, alignment: .leading)

                    DatePicker("Time", selection: Binding(
                        get: { folderStore.scheduleTime },
                        set: { folderStore.updateScheduleTime($0) }
                    ), displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .disabled(!folderStore.scheduleEnabled)

                    Spacer()
                }
            }
        }
    }

    private var backgroundSection: some View {
        SectionCard(title: "Background Sync", subtitle: "Run even when the app is closed.") {
            VStack(alignment: .leading, spacing: 12) {
                Text(folderStore.launchAgentInstalled ? "Launch Agent installed." : "Not installed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Spacer()
                    Button("Install / Update") {
                        folderStore.installLaunchAgent()
                    }

                    Button("Remove") {
                        folderStore.removeLaunchAgent()
                    }
                    .tint(.red)
                }

                Text("Uses your current schedule time. Update schedule and reinstall to apply.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var serverSection: some View {
        SectionCard(title: "Server", subtitle: "Instance status.") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(folderStore.serverVersion.isEmpty ? "Server version unknown" : "Server \(folderStore.serverVersion)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") {
                        folderStore.refreshServerInfo()
                    }
                }
            }
        }
    }

    private var duplicatesSection: some View {
        SectionCard(title: "Duplicates", subtitle: "Detect duplicates on your server.") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Groups: \(folderStore.duplicateGroupsCount) · Assets: \(folderStore.duplicatesCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let checked = folderStore.duplicatesLastChecked {
                    Text("Last checked: \(checked.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Refresh Duplicates") {
                        folderStore.refreshDuplicates()
                    }
                }
            }
        }
    }

    private var resetSection: some View {
        SectionCard(title: "Reset", subtitle: "Clear all settings and start fresh.") {
            VStack(alignment: .leading, spacing: 12) {
                Text("This will remove saved folders, API key, schedules, and cached sync state.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    Button("Reset App") {
                        folderStore.resetApp()
                    }
                    .tint(.red)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Image(systemName: "folder.badge.plus")
            Text("Permissions and selections are saved for future launches.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var lockView: some View {
        VStack(alignment: .center, spacing: 12) {
            LogoView(size: 56)
            Text("Unlock to access settings")
                .font(.headline)
            Text("Touch ID is required to open the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(folderStore.isAuthenticating ? "Authenticating..." : "Unlock") {
                folderStore.authenticateUser()
            }
            .disabled(folderStore.isAuthenticating)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var onboardingView: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            OnboardingStepper(step: onboardingStep)

            switch onboardingStep {
            case .credentials:
                onboardingCredentials
            case .downloadFolder:
                onboardingDownloadFolder
            case .uploadFolder:
                onboardingUploadFolder
            case .finish:
                onboardingFinish
            }
        }
        .padding(32)
    }

    private var onboardingCredentials: some View {
        SectionCard(title: "Connect your Immich server", subtitle: "Enter credentials to continue.") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Server URL (https://immich.example.com)", text: Binding(
                    get: { folderStore.serverURL },
                    set: { folderStore.updateServerURL($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

                SecureField("API key", text: $apiKeyDraft)
                    .textFieldStyle(.roundedBorder)

                Toggle("Require Touch ID on launch", isOn: Binding(
                    get: { folderStore.requireTouchID },
                    set: { folderStore.updateRequireTouchID($0) }
                ))

                Toggle("Store API key in Keychain", isOn: Binding(
                    get: { folderStore.useKeychain },
                    set: { folderStore.updateUseKeychain($0) }
                ))
                .disabled(!folderStore.requireTouchID)

                HStack {
                    Spacer()
                    Button("Save & Continue") {
                        folderStore.updateApiKey(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                        onboardingStep = .downloadFolder
                    }
                    .disabled(!isCredentialDraftValid)
                }
            }
        }
    }

    private var onboardingDownloadFolder: some View {
        SectionCard(title: "Choose download folder", subtitle: "Store your Immich assets locally.") {
            VStack(alignment: .leading, spacing: 12) {
                if let url = folderStore.selectedURL {
                    Text(url.path)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text("No folder selected yet.")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Choose Folder") {
                        folderStore.chooseFolder()
                    }

                    Button("Skip") {
                        onboardingStep = .uploadFolder
                    }
                }

                HStack {
                    Spacer()
                    Button("Continue") {
                        onboardingStep = .uploadFolder
                    }
                    .disabled(folderStore.selectedURL == nil)
                }
            }
        }
    }

    private var onboardingUploadFolder: some View {
        SectionCard(title: "Choose upload watch folder", subtitle: "Optional: auto-upload new files.") {
            VStack(alignment: .leading, spacing: 12) {
                if let url = folderStore.uploadFolderURL {
                    Text(url.path)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text("No upload folder selected yet.")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Choose Folder") {
                        folderStore.chooseUploadFolder()
                    }

                    Button("Skip") {
                        onboardingStep = .finish
                    }
                }

                HStack {
                    Spacer()
                    Button("Continue") {
                        onboardingStep = .finish
                    }
                }
            }
        }
    }

    private var onboardingFinish: some View {
        SectionCard(title: "All set", subtitle: "You can start syncing right away.") {
            VStack(alignment: .leading, spacing: 12) {
                Text("You can adjust filters, scheduling, and upload settings anytime.")
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    Button("Open Dashboard") {
                        selectedSection = .download
                    }
                }
            }
        }
    }

    private var isCredentialDraftValid: Bool {
        let urlOK = folderStore.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("http")
        let keyOK = !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return urlOK && keyOK
    }
}

private enum AppSection: Hashable {
    case download
    case upload
    case connection
    case schedule
    case background
    case server
    case duplicates
    case reset
}

private enum OnboardingStep: Int {
    case credentials
    case downloadFolder
    case uploadFolder
    case finish
}

private struct OnboardingStepper: View {
    let step: OnboardingStep

    var body: some View {
        HStack(spacing: 12) {
            stepBadge("Credentials", isActive: step == .credentials)
            stepBadge("Backup", isActive: step == .downloadFolder)
            stepBadge("Upload", isActive: step == .uploadFolder)
            stepBadge("Finish", isActive: step == .finish)
        }
    }

    private func stepBadge(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.15))
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            .clipShape(Capsule())
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(BackupFolderStore())
}
