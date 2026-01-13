import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var folderStore: BackupFolderStore
    @State private var apiKeyDraft = ""
    @State private var selectedSection: AppSection = .dashboard
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
            folderStore.checkConnection()
        }
        .onChange(of: folderStore.resetCounter) { _ in
            apiKeyDraft = ""
            onboardingStep = .credentials
            selectedSection = .dashboard
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
                Label("Dashboard", systemImage: "chart.bar.xaxis").tag(AppSection.dashboard)
                Label("Download", systemImage: "arrow.down.circle").tag(AppSection.download)
                Label("Upload", systemImage: "arrow.up.circle").tag(AppSection.upload)
                Label("History", systemImage: "clock.arrow.circlepath").tag(AppSection.history)
            }
            Section("Settings") {
                Label("Connection", systemImage: "key.horizontal").tag(AppSection.connection)
                Label("Schedule", systemImage: "calendar").tag(AppSection.schedule)
                Label("Background", systemImage: "bolt.badge.clock").tag(AppSection.background)
                Label("Limits", systemImage: "speedometer").tag(AppSection.limits)
            }
            Section("Insights") {
                Label("Analytics", systemImage: "waveform.path.ecg").tag(AppSection.analytics)
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
                case .dashboard:
                    dashboardSection
                case .download:
                    downloadSection
                case .upload:
                    uploadSection
                case .history:
                    historySection
                case .connection:
                    connectionSection
                case .schedule:
                    scheduleSection
                case .background:
                    backgroundSection
                case .limits:
                    limitsSection
                case .analytics:
                    analyticsSection
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

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Overview", subtitle: "At-a-glance sync health.") {
                HStack(spacing: 16) {
                    statTile(title: "Downloaded", value: "\(folderStore.downloadedCount)", subtitle: "assets", color: .blue)
                    statTile(title: "Uploaded", value: "\(folderStore.uploadedCount)", subtitle: "assets", color: .orange)
                    statTile(title: "Local duplicates", value: "\(folderStore.localDuplicatesCount)", subtitle: "assets", color: .purple)
                }
            }

            SectionCard(title: "Status", subtitle: "Latest activity and next steps.") {
                VStack(alignment: .leading, spacing: 12) {
                    if let lastSync = folderStore.lastSyncDate {
                        Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No syncs yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if folderStore.isDownloading {
                        Text(folderStore.progressText.isEmpty ? "Downloading..." : folderStore.progressText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if folderStore.isUploading {
                        Text(folderStore.uploadProgressText.isEmpty ? "Uploading..." : folderStore.uploadProgressText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    transferStatusView

                    HStack(spacing: 12) {
                        Spacer()
                        Button("Sync Now") {
                            folderStore.startDownloadAllAssets()
                        }
                        .disabled(folderStore.isDownloading)

                        Button("Upload Now") {
                            folderStore.startUploadNow()
                        }
                        .disabled(folderStore.isUploading)
                    }
                }
            }
        }
    }

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Download Analytics", subtitle: "Live speed and throughput.") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(folderStore.speedText.isEmpty ? "No download activity yet." : folderStore.speedText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !folderStore.downloadSpeedSamples.isEmpty {
                        SpeedGraphView(samples: folderStore.downloadSpeedSamples, color: .blue)
                    }

                    Text("Average: \(averageText(folderStore.downloadSpeedSamples))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SectionCard(title: "Upload Analytics", subtitle: "Live speed and throughput.") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(folderStore.uploadSpeedText.isEmpty ? "No upload activity yet." : folderStore.uploadSpeedText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !folderStore.uploadSpeedSamples.isEmpty {
                        SpeedGraphView(samples: folderStore.uploadSpeedSamples, color: .orange)
                    }

                    Text("Average: \(averageText(folderStore.uploadSpeedSamples))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
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

                Divider()

                HStack(spacing: 12) {
                    Button("Check Connection") {
                        checkConnectionWithDraft()
                    }
                    .disabled(!isCredentialDraftValid)

                    Button("Check Permissions") {
                        checkConnectionWithDraft()
                    }
                    .disabled(!isCredentialDraftValid)
                }

                connectionStatusView

                if !folderStore.connectionWarnings.isEmpty {
                    ForEach(folderStore.connectionWarnings, id: \.self) { warning in
                        Text("• \(warning)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Albums")
                                .frame(width: 60, alignment: .leading)
                            Spacer()
                            Button("Refresh") {
                                folderStore.refreshAlbums()
                            }
                        }

                        HStack(spacing: 12) {
                            Button("Select all") {
                                folderStore.updateSelectedAlbumIDs(folderStore.albums.map { $0.id })
                            }
                            Button("Clear") {
                                folderStore.updateSelectedAlbumIDs([])
                            }
                            Text("\(folderStore.selectedAlbumIDs.count) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(folderStore.albums) { album in
                                    Button {
                                        toggleAlbumSelection(album.id)
                                    } label: {
                                        HStack {
                                            Image(systemName: folderStore.selectedAlbumIDs.contains(album.id) ? "checkmark.square.fill" : "square")
                                            Text("\(album.name) (\(album.assetCount))")
                                                .font(.footnote)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 160)
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

                    Toggle("Verify downloads (size + checksum)", isOn: Binding(
                        get: { folderStore.verifyIntegrity },
                        set: { folderStore.updateVerifyIntegrity($0) }
                    ))

                    Toggle("Organize by album (Base/Album Name)", isOn: Binding(
                        get: { folderStore.organizeByAlbum },
                        set: { folderStore.updateOrganizeByAlbum($0) }
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

                    downloadCompletionView

                    if !folderStore.downloadSpeedSamples.isEmpty {
                        SpeedGraphView(samples: folderStore.downloadSpeedSamples, color: .blue)
                    }

                    if !folderStore.downloadStatusItems.isEmpty {
                        Divider()
                        HStack {
                            Text("Download status")
                                .font(.footnote.weight(.semibold))
                            Spacer()
                            Picker("Show", selection: Binding(
                                get: { folderStore.downloadStatusLimit },
                                set: { folderStore.updateDownloadStatusLimit($0) }
                            )) {
                                Text("10").tag(10)
                                Text("20").tag(20)
                                Text("50").tag(50)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(limitedDownloadStatusItems()) { item in
                                    HStack {
                                        Text(item.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(downloadStatusLabel(item.status))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 180)
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

                Toggle("Check server for duplicates before upload", isOn: Binding(
                    get: { folderStore.checkServerDuplicatesOnUpload },
                    set: { folderStore.updateCheckServerDuplicatesOnUpload($0) }
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
                    Text("Allow list")
                        .frame(width: 80, alignment: .leading)
                    TextField("jpg,png,heic", text: Binding(
                        get: { folderStore.uploadAllowList },
                        set: { folderStore.updateUploadAllowList($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 12) {
                    Text("Deny list")
                        .frame(width: 80, alignment: .leading)
                    TextField("mov,mp4", text: Binding(
                        get: { folderStore.uploadDenyList },
                        set: { folderStore.updateUploadDenyList($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
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

                    Button("Clear History") {
                        folderStore.clearUploadHistory()
                    }
                    .disabled(folderStore.isUploading)
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

                uploadCompletionView

                if let error = folderStore.uploadLastError, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if folderStore.uploadLocalDuplicateCount > 0 || folderStore.uploadServerDuplicateCount > 0 {
                        Text("Already uploaded: \(folderStore.uploadLocalDuplicateCount) · Server duplicates: \(folderStore.uploadServerDuplicateCount)")
                        .font(.caption)
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
                    HStack {
                        Text("Upload status")
                            .font(.footnote.weight(.semibold))
                        Spacer()
                        Picker("Show", selection: Binding(
                            get: { folderStore.uploadStatusLimit },
                            set: { folderStore.updateUploadStatusLimit($0) }
                        )) {
                            Text("10").tag(10)
                            Text("20").tag(20)
                            Text("50").tag(50)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(limitedUploadStatusItems()) { item in
                                HStack {
                                    Text(URL(fileURLWithPath: item.path).lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(uploadStatusLabel(item))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 180)
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
        SectionCard(title: "Server", subtitle: "Instance status and credentials.") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Server URL (https://immich.example.com)", text: Binding(
                    get: { folderStore.serverURL },
                    set: { folderStore.updateServerURL($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

                HStack {
                    Text(folderStore.serverVersion.isEmpty ? "Server version unknown" : "Server \(folderStore.serverVersion)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") {
                        folderStore.refreshServerInfo()
                    }
                }

                SecureField("API key", text: $apiKeyDraft)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button("Save API Key") {
                        folderStore.updateApiKey(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .disabled(!isCredentialDraftValid)
                }
            }
        }
    }

    private var duplicatesSection: some View {
        SectionCard(title: "Duplicates", subtitle: "Local and server duplicate insights.") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Local duplicates: \(folderStore.localDuplicatesCount)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let checked = folderStore.localDuplicatesLastChecked {
                        Text("Last scanned: \(checked.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Spacer()
                        Button("Scan Local Duplicates") {
                            folderStore.scanLocalDuplicates()
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Server duplicates: \(folderStore.duplicatesCount) assets · \(folderStore.duplicateGroupsCount) groups")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let checked = folderStore.duplicatesLastChecked {
                        Text("Server checked: \(checked.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Spacer()
                        Button("Refresh Server Duplicates") {
                            folderStore.refreshDuplicates()
                        }
                    }
                }
            }
        }
    }

    private var historySection: some View {
        SectionCard(title: "Sync History", subtitle: "Recent download/upload runs.") {
            VStack(alignment: .leading, spacing: 12) {
                if folderStore.syncHistory.isEmpty {
                    Text("No history yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(folderStore.syncHistory.prefix(10)) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.type.capitalized)
                                    .font(.footnote.weight(.semibold))
                                Text(item.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("D:\(item.downloaded) U:\(item.uploaded) S:\(item.skipped) E:\(item.errors)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Clear History") {
                        folderStore.clearHistory()
                    }
                    .tint(.red)

                    Button("Export Error Log") {
                        folderStore.exportErrorLog()
                    }
                    .disabled(!folderStore.hasErrorLog)
                }
            }
        }
    }

    private var limitsSection: some View {
        SectionCard(title: "Bandwidth & Power", subtitle: "Control transfer limits and power behavior.") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Download limit (MB/s)")
                    Spacer()
                    TextField("0", value: Binding(
                        get: { folderStore.downloadBandwidthLimit },
                        set: { folderStore.updateDownloadBandwidthLimit($0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }

                HStack {
                    Text("Upload limit (MB/s)")
                    Spacer()
                    TextField("0", value: Binding(
                        get: { folderStore.uploadBandwidthLimit },
                        set: { folderStore.updateUploadBandwidthLimit($0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }

                Toggle("Auto‑pause on battery or Low Power Mode", isOn: Binding(
                    get: { folderStore.autoPauseOnBattery },
                    set: { folderStore.updateAutoPauseOnBattery($0) }
                ))

                Toggle("Enable notifications", isOn: Binding(
                    get: { folderStore.notificationsEnabled },
                    set: { folderStore.updateNotificationsEnabled($0) }
                ))

                if folderStore.isPausedForPower {
                    Text("Sync paused due to power settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    Button("Export Error Log") {
                        folderStore.exportErrorLog()
                    }
                    .disabled(!folderStore.hasErrorLog)

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

    private func statTile(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }

    private func averageText(_ samples: [Double]) -> String {
        guard !samples.isEmpty else { return "0.00 MB/s" }
        let avg = samples.reduce(0, +) / Double(samples.count)
        return String(format: "%.2f MB/s", avg)
    }

    private var transferStatusView: some View {
        HStack(spacing: 8) {
            if folderStore.isDownloading || folderStore.isUploading {
                ProgressView()
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            Text(transferStatusText())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(transferStatusColor())
        }
    }

    private func transferStatusText() -> String {
        if folderStore.isDownloading {
            return "Transfer active (download)"
        }
        if folderStore.isUploading {
            return "Transfer active (upload)"
        }
        return "Idle"
    }

    private func transferStatusColor() -> Color {
        if folderStore.isDownloading {
            return .blue
        }
        if folderStore.isUploading {
            return .orange
        }
        return .secondary
    }

    private var downloadCompletionView: some View {
        completionView(
            isActive: folderStore.isDownloading,
            state: folderStore.downloadCompletionState,
            idleText: "Download idle",
            successText: "Download complete",
            failedText: "Download failed",
            activeText: "Looking for new data"
        )
    }

    private var uploadCompletionView: some View {
        completionView(
            isActive: folderStore.isUploading,
            state: folderStore.uploadCompletionState,
            idleText: "Upload idle",
            successText: "Upload complete",
            failedText: "Upload failed",
            activeText: "Uploading..."
        )
    }

    private func completionView(isActive: Bool, state: BackupFolderStore.CompletionState, idleText: String, successText: String, failedText: String, activeText: String) -> some View {
        HStack(spacing: 8) {
            if isActive {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.85)
                    .tint(.orange)
                Text(activeText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            } else {
                switch state {
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(successText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.green)
                case .failed:
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text(failedText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                case .idle:
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                    Text(idleText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func uploadStatusLabel(_ item: BackupFolderStore.UploadQueueItem) -> String {
        if item.status == .skipped {
            if let error = item.error, !error.isEmpty {
                return error
            }
            return "Skipped"
        }
        switch item.status {
        case .queued:
            return "Queued"
        case .uploading:
            return "Uploading"
        case .done:
            return "Done"
        case .failed:
            return "Failed"
        case .skipped:
            return "Skipped"
        }
    }

    private func downloadStatusLabel(_ status: BackupFolderStore.DownloadStatus) -> String {
        switch status {
        case .downloading:
            return "Downloading"
        case .done:
            return "Done"
        case .skipped:
            return "Duplicate"
        case .failed:
            return "Failed"
        }
    }

    private func limitedUploadStatusItems() -> [BackupFolderStore.UploadQueueItem] {
        let limit = max(1, folderStore.uploadStatusLimit)
        return Array(folderStore.uploadQueue.suffix(limit)).reversed()
    }

    private func limitedDownloadStatusItems() -> [BackupFolderStore.DownloadStatusItem] {
        let limit = max(1, folderStore.downloadStatusLimit)
        return Array(folderStore.downloadStatusItems.suffix(limit)).reversed()
    }

    private func toggleAlbumSelection(_ id: String) {
        var current = folderStore.selectedAlbumIDs
        if let index = current.firstIndex(of: id) {
            current.remove(at: index)
        } else {
            current.append(id)
        }
        folderStore.updateSelectedAlbumIDs(current)
    }


    private var connectionStatusView: some View {
        HStack(spacing: 8) {
            if folderStore.isCheckingConnection {
                ProgressView()
            } else {
                Image(systemName: connectionIconName())
                    .foregroundStyle(connectionIconColor())
            }
            Text(folderStore.connectionStatus)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(connectionIconColor())
        }
    }

    private func connectionIconName() -> String {
        switch folderStore.connectionState {
        case .ok:
            return "checkmark.circle.fill"
        case .limited:
            return "exclamationmark.triangle.fill"
        case .invalid:
            return "xmark.octagon.fill"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .idle:
            return "questionmark.circle.fill"
        }
    }

    private func connectionIconColor() -> Color {
        switch folderStore.connectionState {
        case .ok:
            return .green
        case .limited:
            return .orange
        case .invalid:
            return .red
        case .checking:
            return .blue
        case .idle:
            return .secondary
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
                        checkConnectionWithDraft()
                        onboardingStep = .downloadFolder
                    }
                    .disabled(!isCredentialDraftValid)
                }

                HStack(spacing: 12) {
                    Button("Check Connection") {
                        checkConnectionWithDraft()
                    }
                    .disabled(!isCredentialDraftValid)

                    Button("Check Permissions") {
                        checkConnectionWithDraft()
                    }
                    .disabled(!isCredentialDraftValid)
                }

                connectionStatusView

                if !folderStore.connectionWarnings.isEmpty {
                    ForEach(folderStore.connectionWarnings, id: \.self) { warning in
                        Text("• \(warning)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                        selectedSection = .dashboard
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

    private func checkConnectionWithDraft() {
        let server = folderStore.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        folderStore.checkConnection(serverURL: server, apiKey: key)
    }
}

private enum AppSection: Hashable {
    case dashboard
    case download
    case upload
    case history
    case connection
    case schedule
    case background
    case limits
    case analytics
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
