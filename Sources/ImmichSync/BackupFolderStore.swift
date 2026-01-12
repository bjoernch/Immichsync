import AppKit
import Foundation
import LocalAuthentication

final class BackupFolderStore: ObservableObject {
    struct Album: Identifiable, Hashable {
        let id: String
        let name: String
        let assetCount: Int
    }

    enum UploadStatus: String {
        case queued
        case uploading
        case done
        case skipped
        case failed
    }

    struct UploadQueueItem: Identifiable, Hashable {
        let id: UUID
        let path: String
        var status: UploadStatus
        var error: String?
    }


    @Published private(set) var selectedURL: URL?
    @Published var serverURL: String
    @Published var apiKey: String
    @Published var useKeychain: Bool
    @Published var requireTouchID: Bool
    @Published var includePhotos: Bool
    @Published var includeVideos: Bool
    @Published var skipTrashed: Bool
    @Published var downloadFolderStructure: String
    @Published var writeSidecarMetadata: Bool
    @Published var selectedAlbumID: String
    @Published var scheduleEnabled: Bool
    @Published var scheduleTime: Date
    @Published private(set) var albums: [Album] = []
    @Published private(set) var serverVersion: String = ""
    @Published private(set) var duplicatesCount: Int = 0
    @Published private(set) var duplicateGroupsCount: Int = 0
    @Published private(set) var duplicatesLastChecked: Date?
    @Published private(set) var launchAgentInstalled: Bool = false
    @Published var uploadEnabled: Bool
    @Published var includeUploadSubfolders: Bool
    @Published var uploadIncludePhotos: Bool
    @Published var uploadIncludeVideos: Bool
    @Published private(set) var uploadFolderURL: URL?
    @Published private(set) var isUploading = false
    @Published private(set) var uploadProgressText = ""
    @Published private(set) var uploadSpeedText = ""
    @Published private(set) var uploadQueue: [UploadQueueItem] = []
    @Published private(set) var isDownloading = false
    @Published private(set) var progressText = ""
    @Published private(set) var progressValue: Double = 0
    @Published private(set) var speedText = ""
    @Published private(set) var downloadSpeedSamples: [Double] = []
    @Published private(set) var uploadSpeedSamples: [Double] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var isUnlocked = false
    @Published private(set) var isAuthenticating = false

    private let defaults = UserDefaults.standard
    private let urlSession = URLSession.shared
    private let downloadIndex = DownloadIndex()
    private var downloadTask: Task<Void, Never>?
    private var scheduleTimer: Timer?
    private var bytesDownloaded: Int64 = 0
    private var downloadStartDate: Date?
    private var pendingIndexFlush = 0
    private let uploadIndex = UploadIndex()
    private var uploadTask: Task<Void, Never>?
    private var uploadMonitor: DispatchSourceFileSystemObject?
    private var uploadMonitorFD: CInt = -1
    private var uploadDebounceTimer: Timer?
    private var uploadScanTimer: Timer?
    private var bytesUploaded: Int64 = 0
    private var uploadStartDate: Date?
    private let deviceID: String
    private var uploadRescanPending = false

    private enum Keys {
        static let bookmark = "backupFolderBookmark"
        static let path = "backupFolderPath"
        static let uploadBookmark = "uploadFolderBookmark"
        static let uploadPath = "uploadFolderPath"
        static let serverURL = "immichServerURL"
        static let apiKey = "immichApiKey"
        static let useKeychain = "useKeychain"
        static let requireTouchID = "requireTouchID"
        static let includePhotos = "includePhotos"
        static let includeVideos = "includeVideos"
        static let skipTrashed = "skipTrashed"
        static let downloadFolderStructure = "downloadFolderStructure"
        static let writeSidecarMetadata = "writeSidecarMetadata"
        static let selectedAlbumID = "selectedAlbumID"
        static let uploadEnabled = "uploadEnabled"
        static let includeUploadSubfolders = "includeUploadSubfolders"
        static let uploadIncludePhotos = "uploadIncludePhotos"
        static let uploadIncludeVideos = "uploadIncludeVideos"
        static let deviceID = "deviceID"
        static let scheduleEnabled = "scheduleEnabled"
        static let scheduleTime = "scheduleTime"
        static let lastSyncDate = "lastSyncDate"
    }

    private enum KeychainKeys {
        static let service = "ImmichSync"
        static let apiKeyAccount = "apiKey"
    }

    init() {
        serverURL = defaults.string(forKey: Keys.serverURL) ?? ""
        apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        useKeychain = defaults.object(forKey: Keys.useKeychain) as? Bool ?? false
        requireTouchID = defaults.object(forKey: Keys.requireTouchID) as? Bool ?? false
        includePhotos = defaults.object(forKey: Keys.includePhotos) as? Bool ?? true
        includeVideos = defaults.object(forKey: Keys.includeVideos) as? Bool ?? true
        skipTrashed = defaults.object(forKey: Keys.skipTrashed) as? Bool ?? true
        downloadFolderStructure = defaults.string(forKey: Keys.downloadFolderStructure) ?? "flat"
        writeSidecarMetadata = defaults.object(forKey: Keys.writeSidecarMetadata) as? Bool ?? true
        selectedAlbumID = defaults.string(forKey: Keys.selectedAlbumID) ?? ""
        uploadEnabled = defaults.object(forKey: Keys.uploadEnabled) as? Bool ?? false
        includeUploadSubfolders = defaults.object(forKey: Keys.includeUploadSubfolders) as? Bool ?? true
        uploadIncludePhotos = defaults.object(forKey: Keys.uploadIncludePhotos) as? Bool ?? true
        uploadIncludeVideos = defaults.object(forKey: Keys.uploadIncludeVideos) as? Bool ?? true
        scheduleEnabled = defaults.object(forKey: Keys.scheduleEnabled) as? Bool ?? false
        scheduleTime = defaults.object(forKey: Keys.scheduleTime) as? Date ?? Date()
        if let storedDevice = defaults.string(forKey: Keys.deviceID) {
            deviceID = storedDevice
        } else {
            let newDevice = UUID().uuidString
            deviceID = newDevice
            defaults.set(newDevice, forKey: Keys.deviceID)
        }
        if let lastSync = defaults.object(forKey: Keys.lastSyncDate) as? Date {
            lastSyncDate = lastSync
        }

        loadBookmark()
        loadUploadBookmark()
        configureSchedule()
        configureUploadMonitoring()
        launchAgentInstalled = FileManager.default.fileExists(atPath: launchAgentPlistURL().path)
        isUnlocked = !requireTouchID
    }

    func updateServerURL(_ value: String) {
        serverURL = value
        defaults.set(value, forKey: Keys.serverURL)
    }

    func updateApiKey(_ value: String) {
        apiKey = value
        defaults.set(value, forKey: Keys.apiKey)
        if useKeychain {
            KeychainStore.write(value, service: KeychainKeys.service, account: KeychainKeys.apiKeyAccount)
        }
    }

    func updateUseKeychain(_ value: Bool) {
        useKeychain = value
        defaults.set(value, forKey: Keys.useKeychain)
        if !value {
            KeychainStore.delete(service: KeychainKeys.service, account: KeychainKeys.apiKeyAccount)
        }
    }

    func updateRequireTouchID(_ value: Bool) {
        requireTouchID = value
        defaults.set(value, forKey: Keys.requireTouchID)
        if value {
            isUnlocked = false
            authenticateUser()
        } else {
            updateUseKeychain(false)
            isUnlocked = true
        }
    }

    func updateIncludePhotos(_ value: Bool) {
        includePhotos = value
        defaults.set(value, forKey: Keys.includePhotos)
    }

    func updateIncludeVideos(_ value: Bool) {
        includeVideos = value
        defaults.set(value, forKey: Keys.includeVideos)
    }

    func updateSkipTrashed(_ value: Bool) {
        skipTrashed = value
        defaults.set(value, forKey: Keys.skipTrashed)
    }

    func updateDownloadFolderStructure(_ value: String) {
        downloadFolderStructure = value
        defaults.set(value, forKey: Keys.downloadFolderStructure)
    }

    func updateWriteSidecarMetadata(_ value: Bool) {
        writeSidecarMetadata = value
        defaults.set(value, forKey: Keys.writeSidecarMetadata)
    }

    func updateSelectedAlbumID(_ value: String) {
        selectedAlbumID = value
        defaults.set(value, forKey: Keys.selectedAlbumID)
    }

    func updateScheduleEnabled(_ value: Bool) {
        scheduleEnabled = value
        defaults.set(value, forKey: Keys.scheduleEnabled)
        configureSchedule()
    }

    func updateScheduleTime(_ value: Date) {
        scheduleTime = value
        defaults.set(value, forKey: Keys.scheduleTime)
        configureSchedule()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Backup Folder"
        panel.prompt = "Select"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            storeSelection(url)
        }
    }

    func chooseUploadFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Upload Watch Folder"
        panel.prompt = "Select"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            storeUploadSelection(url)
        }
    }

    func clearSelection() {
        selectedURL = nil
        defaults.removeObject(forKey: Keys.bookmark)
        defaults.removeObject(forKey: Keys.path)
    }

    func clearUploadSelection() {
        uploadFolderURL = nil
        defaults.removeObject(forKey: Keys.uploadBookmark)
        defaults.removeObject(forKey: Keys.uploadPath)
        configureUploadMonitoring()
    }

    func startDownloadAllAssets() {
        guard !isDownloading else { return }
        downloadTask = Task { await downloadAllAssets() }
    }

    func stopDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        progressText = "Stopped."
    }

    func updateUploadEnabled(_ value: Bool) {
        uploadEnabled = value
        defaults.set(value, forKey: Keys.uploadEnabled)
        configureUploadMonitoring()
        if value {
            startUploadNow()
        }
    }

    func updateIncludeUploadSubfolders(_ value: Bool) {
        includeUploadSubfolders = value
        defaults.set(value, forKey: Keys.includeUploadSubfolders)
    }

    func updateUploadIncludePhotos(_ value: Bool) {
        uploadIncludePhotos = value
        defaults.set(value, forKey: Keys.uploadIncludePhotos)
    }

    func updateUploadIncludeVideos(_ value: Bool) {
        uploadIncludeVideos = value
        defaults.set(value, forKey: Keys.uploadIncludeVideos)
    }

    func startUploadNow() {
        guard !isUploading else { return }
        uploadTask = Task { await uploadAssetsFromFolder() }
    }

    func stopUpload() {
        uploadTask?.cancel()
        uploadTask = nil
        isUploading = false
        uploadProgressText = "Stopped."
    }

    func revealInFinder() {
        guard let url = selectedURL else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func refreshAlbums() {
        Task { await loadAlbums() }
    }

    func refreshServerInfo() {
        Task {
            await loadServerVersion()
        }
    }

    func refreshDuplicates() {
        Task { await loadDuplicates() }
    }

    func resetApp() {
        stopDownload()
        stopUpload()
        uploadMonitor?.cancel()
        uploadMonitor = nil
        uploadDebounceTimer?.invalidate()
        uploadDebounceTimer = nil
        uploadScanTimer?.invalidate()
        uploadScanTimer = nil

        KeychainStore.delete(service: KeychainKeys.service, account: KeychainKeys.apiKeyAccount)
        removeLaunchAgent()

        let keysToClear: [String] = [
            Keys.bookmark,
            Keys.path,
            Keys.uploadBookmark,
            Keys.uploadPath,
            Keys.serverURL,
            Keys.apiKey,
            Keys.includePhotos,
            Keys.includeVideos,
            Keys.skipTrashed,
            Keys.downloadFolderStructure,
            Keys.writeSidecarMetadata,
            Keys.selectedAlbumID,
            Keys.uploadEnabled,
            Keys.includeUploadSubfolders,
            Keys.uploadIncludePhotos,
            Keys.uploadIncludeVideos,
            Keys.useKeychain,
            Keys.requireTouchID,
            Keys.scheduleEnabled,
            Keys.scheduleTime,
            Keys.lastSyncDate
        ]

        for key in keysToClear {
            defaults.removeObject(forKey: key)
        }

        downloadIndex.save()
        uploadIndex.save()

        selectedURL = nil
        uploadFolderURL = nil
        serverURL = ""
        apiKey = ""
        useKeychain = false
        requireTouchID = false
        includePhotos = true
        includeVideos = true
        skipTrashed = true
        downloadFolderStructure = "flat"
        writeSidecarMetadata = true
        selectedAlbumID = ""
        uploadEnabled = false
        includeUploadSubfolders = true
        uploadIncludePhotos = true
        uploadIncludeVideos = true
        scheduleEnabled = false
        scheduleTime = Date()
        albums = []
        serverVersion = ""
        duplicatesCount = 0
        duplicateGroupsCount = 0
        duplicatesLastChecked = nil
        launchAgentInstalled = false
        uploadProgressText = ""
        uploadSpeedText = ""
        uploadQueue = []
        isDownloading = false
        progressText = ""
        progressValue = 0
        speedText = ""
        downloadSpeedSamples = []
        uploadSpeedSamples = []
        lastError = nil
        lastSyncDate = nil
        isUnlocked = true
        isAuthenticating = false
    }

    func authenticateUser() {
        guard requireTouchID else {
            isUnlocked = true
            return
        }
        guard !isAuthenticating else { return }
        isAuthenticating = true

        let context = LAContext()
        var error: NSError?
        let reason = "Unlock ImmichSync"

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, _ in
                DispatchQueue.main.async {
                    self?.isUnlocked = success
                    self?.isAuthenticating = false
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, _ in
                DispatchQueue.main.async {
                    self?.isUnlocked = success
                    self?.isAuthenticating = false
                }
            }
        } else {
            isUnlocked = true
            isAuthenticating = false
        }
    }

    func ensureUnlockState() {
        if requireTouchID {
            authenticateUser()
        } else {
            isUnlocked = true
        }
    }

    private func storeSelection(_ url: URL) {
        selectedURL = url
        defaults.set(url.path, forKey: Keys.path)

        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(data, forKey: Keys.bookmark)
        } catch {
            defaults.removeObject(forKey: Keys.bookmark)
        }
    }

    private func storeUploadSelection(_ url: URL) {
        uploadFolderURL = url
        defaults.set(url.path, forKey: Keys.uploadPath)

        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(data, forKey: Keys.uploadBookmark)
        } catch {
            defaults.removeObject(forKey: Keys.uploadBookmark)
        }

        configureUploadMonitoring()
    }

    private func loadBookmark() {
        if let data = defaults.data(forKey: Keys.bookmark) {
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                selectedURL = url
                if stale {
                    storeSelection(url)
                }
                return
            } catch {
                defaults.removeObject(forKey: Keys.bookmark)
            }
        }

        if let path = defaults.string(forKey: Keys.path) {
            selectedURL = URL(fileURLWithPath: path)
        }
    }

    private func loadUploadBookmark() {
        if let data = defaults.data(forKey: Keys.uploadBookmark) {
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                uploadFolderURL = url
                if stale {
                    storeUploadSelection(url)
                }
                return
            } catch {
                defaults.removeObject(forKey: Keys.uploadBookmark)
            }
        }

        if let path = defaults.string(forKey: Keys.uploadPath) {
            uploadFolderURL = URL(fileURLWithPath: path)
        }
    }

    private func configureUploadMonitoring() {
        uploadDebounceTimer?.invalidate()
        uploadDebounceTimer = nil
        uploadScanTimer?.invalidate()
        uploadScanTimer = nil

        if let monitor = uploadMonitor {
            monitor.cancel()
            uploadMonitor = nil
        }

        if uploadMonitorFD >= 0 {
            close(uploadMonitorFD)
            uploadMonitorFD = -1
        }

        guard uploadEnabled, let url = uploadFolderURL else { return }

        uploadMonitorFD = open(url.path, O_EVTONLY)
        guard uploadMonitorFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: uploadMonitorFD,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            self?.scheduleUploadScan()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.uploadMonitorFD, fd >= 0 {
                close(fd)
                self?.uploadMonitorFD = -1
            }
        }
        source.resume()
        uploadMonitor = source

        uploadScanTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.startUploadNow()
        }
    }

    private func scheduleUploadScan() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            uploadDebounceTimer?.invalidate()
            uploadRescanPending = true
            uploadDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                guard let self else { return }
                if self.isUploading {
                    return
                }
                self.startUploadNow()
            }
        }
    }

    private func configureSchedule() {
        scheduleTimer?.invalidate()
        scheduleTimer = nil

        guard scheduleEnabled else { return }
        let nextFire = nextScheduledDate(from: scheduleTime)
        let timer = Timer(fireAt: nextFire, interval: 0, target: self, selector: #selector(handleScheduleFire), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        scheduleTimer = timer
    }

    @objc private func handleScheduleFire() {
        if !isDownloading {
            startDownloadAllAssets()
        }
        configureSchedule()
    }

    private func nextScheduledDate(from time: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let now = Date()
        var next = calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: now) ?? now
        if next <= now {
            next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
        }
        return next
    }

    func installLaunchAgent() {
        let plistURL = launchAgentPlistURL()
        let appPath = Bundle.main.bundleURL.path
        let components = Calendar.current.dateComponents([.hour, .minute], from: scheduleTime)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let plist: [String: Any] = [
            "Label": "com.immichbackup.picker",
            "ProgramArguments": ["/usr/bin/open", "-a", appPath, "--args", "--sync-now"],
            "StartCalendarInterval": ["Hour": hour, "Minute": minute],
            "RunAtLoad": false
        ]

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            let dir = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: plistURL, options: [.atomic])
            launchAgentInstalled = true
        } catch {
            launchAgentInstalled = false
        }
    }

    func removeLaunchAgent() {
        let plistURL = launchAgentPlistURL()
        try? FileManager.default.removeItem(at: plistURL)
        launchAgentInstalled = false
    }

    private func launchAgentPlistURL() -> URL {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        let dir = base?.appendingPathComponent("LaunchAgents", isDirectory: true)
        return (dir ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("com.immichbackup.picker.plist")
    }
}

private extension BackupFolderStore {
    struct AssetSummary {
        let id: String
        let originalFileName: String?
        let type: String?
        let isTrashed: Bool
        let createdAt: Date?
    }

    struct UploadResult {
        let assetID: String
        let bytes: Int64
    }

    func downloadAllAssets() async {
        await MainActor.run {
            lastError = nil
            progressValue = 0
            progressText = "Preparing download..."
            speedText = ""
            bytesDownloaded = 0
            downloadStartDate = Date()
            downloadSpeedSamples = []
            isDownloading = true
        }

        defer {
            Task { @MainActor in
                isDownloading = false
            }
        }

        guard let folderURL = selectedURL else {
            await setError("Pick a backup folder first.")
            return
        }

        let trimmedServer = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedServer.isEmpty else {
            await setError("Server URL is required.")
            return
        }

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await setError("API key is required.")
            return
        }

        if !includePhotos && !includeVideos {
            await setError("Select at least one asset type.")
            return
        }

        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let baseURL = normalizedBaseURL(from: trimmedServer)
        var downloaded = 0
        var skipped = 0
        var total: Int?

        do {
            if !selectedAlbumID.isEmpty {
                let albumAssets = try await fetchAlbumAssets(baseURL: baseURL, albumID: selectedAlbumID)
                total = albumAssets.count

                for asset in albumAssets where assetMatchesFilter(asset) {
                    if Task.isCancelled { return }
                    let destinationURL = destinationURL(for: asset, baseFolder: folderURL)
                    if shouldSkip(assetID: asset.id, destinationURL: destinationURL) {
                        skipped += 1
                        await updateProgress(downloaded: downloaded, skipped: skipped, total: total)
                        continue
                    }

                    let size = try await downloadAsset(baseURL: baseURL, assetID: asset.id, to: destinationURL)
                    if writeSidecarMetadata {
                        try? await writeSidecarMetadata(baseURL: baseURL, assetID: asset.id, destinationURL: destinationURL)
                    }
                    downloadIndex.add(asset.id)
                    pendingIndexFlush += 1
                    bytesDownloaded += size
                    downloaded += 1
                    flushIndexIfNeeded()
                    await updateProgress(downloaded: downloaded, skipped: skipped, total: total)
                }
            } else {
                var page = 1
                while true {
                    if Task.isCancelled { return }
                    let result = try await fetchAssetsPage(baseURL: baseURL, page: page)
                    if let pageTotal = result.total {
                        total = pageTotal
                    }

                    if result.items.isEmpty {
                        break
                    }

                    for asset in result.items where assetMatchesFilter(asset) {
                        if Task.isCancelled { return }
                        let destinationURL = destinationURL(for: asset, baseFolder: folderURL)
                        if shouldSkip(assetID: asset.id, destinationURL: destinationURL) {
                            skipped += 1
                            await updateProgress(downloaded: downloaded, skipped: skipped, total: total)
                            continue
                        }

                        let size = try await downloadAsset(baseURL: baseURL, assetID: asset.id, to: destinationURL)
                        if writeSidecarMetadata {
                            try? await writeSidecarMetadata(baseURL: baseURL, assetID: asset.id, destinationURL: destinationURL)
                        }
                        downloadIndex.add(asset.id)
                        pendingIndexFlush += 1
                        bytesDownloaded += size
                        downloaded += 1
                        flushIndexIfNeeded()
                        await updateProgress(downloaded: downloaded, skipped: skipped, total: total)
                    }

                    page += 1
                }
            }
        } catch {
            await setError("Download failed: \(error.localizedDescription)")
            return
        }

        downloadIndex.save()
        defaults.set(Date(), forKey: Keys.lastSyncDate)
        let downloadedCount = downloaded
        let skippedCount = skipped
        await MainActor.run {
            lastSyncDate = Date()
            progressText = "Done. Downloaded \(downloadedCount), skipped \(skippedCount)."
            progressValue = 1
        }
    }

    func uploadAssetsFromFolder() async {
        await MainActor.run {
            lastError = nil
            uploadProgressText = "Preparing upload..."
            uploadSpeedText = ""
            bytesUploaded = 0
            uploadStartDate = Date()
            uploadSpeedSamples = []
            uploadQueue = []
            isUploading = true
        }

        defer {
            Task { @MainActor in
                isUploading = false
            }
            if uploadRescanPending {
                uploadRescanPending = false
                startUploadNow()
            }
        }

        guard let folderURL = uploadFolderURL else {
            await setUploadError("Pick an upload watch folder first.")
            return
        }

        let trimmedServer = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedServer.isEmpty else {
            await setUploadError("Server URL is required.")
            return
        }

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await setUploadError("API key is required.")
            return
        }

        if !uploadIncludePhotos && !uploadIncludeVideos {
            await setUploadError("Select at least one upload type.")
            return
        }

        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let baseURL = normalizedBaseURL(from: trimmedServer)
        let fileManager = FileManager.default
        let fileURLs = collectUploadFiles(in: folderURL, fileManager: fileManager)
        if fileURLs.isEmpty {
            await setUploadError("No files found to upload.")
            return
        }

        var uploaded = 0
        var skipped = 0
        let total = fileURLs.count
        let queueItems = fileURLs.map { url in
            UploadQueueItem(id: UUID(), path: url.path, status: .queued, error: nil)
        }
        await MainActor.run {
            uploadQueue = queueItems
        }

        for (index, fileURL) in fileURLs.enumerated() {
            if Task.isCancelled { return }
            let path = fileURL.path
            if uploadIndex.contains(path: path) {
                skipped += 1
                await updateUploadQueue(index: index, status: .skipped, error: nil)
                await updateUploadProgress(uploaded: uploaded, skipped: skipped, total: total)
                continue
            }

            do {
                await updateUploadQueue(index: index, status: .uploading, error: nil)
                let result = try await uploadAssetFile(baseURL: baseURL, fileURL: fileURL)
                uploadIndex.add(path: path, assetID: result.assetID)
                bytesUploaded += result.bytes
                uploaded += 1
                uploadIndex.save()
                await updateUploadQueue(index: index, status: .done, error: nil)
                await updateUploadProgress(uploaded: uploaded, skipped: skipped, total: total)
            } catch {
                await updateUploadQueue(index: index, status: .failed, error: error.localizedDescription)
                await setUploadError("Upload failed: \(error.localizedDescription)")
                return
            }
        }

        let uploadedCount = uploaded
        let skippedCount = skipped
        await MainActor.run {
            uploadProgressText = "Done. Uploaded \(uploadedCount), skipped \(skippedCount)."
            uploadSpeedText = currentUploadSpeedText()
        }
    }

    func shouldSkip(assetID: String, destinationURL: URL) -> Bool {
        if downloadIndex.contains(assetID) {
            return true
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            downloadIndex.add(assetID)
            return true
        }
        return false
    }

    func assetMatchesFilter(_ asset: AssetSummary) -> Bool {
        if skipTrashed && asset.isTrashed {
            return false
        }
        guard let type = asset.type else { return true }
        if includePhotos && includeVideos { return true }
        if includePhotos { return type == "IMAGE" }
        if includeVideos { return type == "VIDEO" }
        return false
    }

    func flushIndexIfNeeded() {
        if pendingIndexFlush >= 25 {
            downloadIndex.save()
            pendingIndexFlush = 0
        }
    }

    func normalizedBaseURL(from server: String) -> URL {
        let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/api") {
            return URL(string: trimmed) ?? URL(string: trimmed + "/api")!
        }
        if trimmed.hasSuffix("/api/") {
            let withoutSlash = String(trimmed.dropLast())
            return URL(string: withoutSlash) ?? URL(string: withoutSlash + "/api")!
        }
        let normalized = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: normalized + "/api") ?? URL(string: normalized)!
    }

    func fetchAssetsPage(baseURL: URL, page: Int) async throws -> (items: [AssetSummary], total: Int?) {
        let url = baseURL.appendingPathComponent("search/metadata")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        var body: [String: Any] = [
            "page": page,
            "size": 100
        ]

        if includePhotos != includeVideos {
            body["type"] = includePhotos ? "IMAGE" : "VIDEO"
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response, data: data)
        return parseAssets(from: data)
    }

    func fetchAlbumAssets(baseURL: URL, albumID: String) async throws -> [AssetSummary] {
        let url = baseURL.appendingPathComponent("albums/\(albumID)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response, data: data)
        return parseAlbumAssets(from: data)
    }

    func downloadAsset(baseURL: URL, assetID: String, to destinationURL: URL) async throws -> Int64 {
        let url = baseURL.appendingPathComponent("assets/\(assetID)/original")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (tempURL, response) = try await urlSession.download(for: request)
        try validateResponse(response, data: nil)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: tempURL)
            return 0
        }

        do {
            try fileManager.moveItem(at: tempURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.moveItem(at: tempURL, to: destinationURL)
        }

        let attrs = try? fileManager.attributesOfItem(atPath: destinationURL.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    func uploadAssetFile(baseURL: URL, fileURL: URL) async throws -> UploadResult {
        let url = baseURL.appendingPathComponent("assets")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let createdAt = (attributes[.creationDate] as? Date) ?? Date()
        let modifiedAt = (attributes[.modificationDate] as? Date) ?? createdAt
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        let formatter = ISO8601DateFormatter()
        let fields: [String: String] = [
            "deviceAssetId": UUID().uuidString,
            "deviceId": deviceID,
            "fileCreatedAt": formatter.string(from: createdAt),
            "fileModifiedAt": formatter.string(from: modifiedAt),
            "assetCreatedAt": formatter.string(from: createdAt)
        ]

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let fileData = try Data(contentsOf: fileURL)
        let body = makeMultipartBody(fields: fields, fileField: "assetData", fileURL: fileURL, fileData: fileData, boundary: boundary)
        request.httpBody = body

        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response, data: data)
        let assetID = parseUploadResponse(from: data)
        return UploadResult(assetID: assetID, bytes: fileSize)
    }

    func makeMultipartBody(fields: [String: String], fileField: String, fileURL: URL, fileData: Data, boundary: String) -> Data {
        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        let filename = fileURL.lastPathComponent
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(fileData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        return body
    }

    func parseUploadResponse(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []),
           let dict = json as? [String: Any],
           let id = dict["id"] as? String {
            return id
        }
        return UUID().uuidString
    }

    func collectUploadFiles(in folderURL: URL, fileManager: FileManager) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        if includeUploadSubfolders {
            let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
            var files: [URL] = []
            while let item = enumerator?.nextObject() as? URL {
                let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
                if values?.isDirectory == true { continue }
                if values?.isRegularFile == true, matchesUploadType(for: item) { files.append(item) }
            }
            return files
        }

        let urls = (try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return urls.filter { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            return values?.isRegularFile == true && matchesUploadType(for: url)
        }
    }

    func matchesUploadType(for url: URL) -> Bool {
        if uploadIncludePhotos && uploadIncludeVideos { return true }
        let ext = url.pathExtension.lowercased()
        if uploadIncludePhotos, photoExtensions().contains(ext) { return true }
        if uploadIncludeVideos, videoExtensions().contains(ext) { return true }
        return false
    }

    func photoExtensions() -> Set<String> {
        ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "bmp", "webp", "dng", "raw"]
    }

    func videoExtensions() -> Set<String> {
        ["mov", "mp4", "m4v", "avi", "mkv", "webm", "3gp"]
    }

    func validateResponse(_ response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let message: String
            if let data, let body = String(data: data, encoding: .utf8), !body.isEmpty {
                message = body
            } else {
                message = "HTTP \(http.statusCode)"
            }
            throw NSError(domain: "ImmichSync", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    func parseAssets(from data: Data) -> (items: [AssetSummary], total: Int?) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let root = json as? [String: Any] else {
            return ([], nil)
        }

        var total: Int?
        var itemsArray: [[String: Any]] = []

        if let assets = root["assets"] as? [String: Any] {
            total = assets["total"] as? Int
            if let items = assets["items"] as? [[String: Any]] {
                itemsArray = items
            }
        } else if let assets = root["assets"] as? [[String: Any]] {
            itemsArray = assets
        } else if let items = root["items"] as? [[String: Any]] {
            itemsArray = items
        }

        let mapped = itemsArray.compactMap { item -> AssetSummary? in
            let id = item["id"] as? String ?? item["assetId"] as? String
            guard let id else { return nil }
            let name = item["originalFileName"] as? String
            let type = item["type"] as? String
            let trashed = (item["isTrashed"] as? Bool) ?? (item["isDeleted"] as? Bool) ?? false
            let createdAt = parseAssetDate(from: item)
            return AssetSummary(id: id, originalFileName: name, type: type, isTrashed: trashed, createdAt: createdAt)
        }

        return (mapped, total)
    }

    func parseAlbumAssets(from data: Data) -> [AssetSummary] {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let root = json as? [String: Any],
              let assets = root["assets"] as? [[String: Any]] else {
            return []
        }

        return assets.compactMap { item -> AssetSummary? in
            let id = item["id"] as? String ?? item["assetId"] as? String
            guard let id else { return nil }
            let name = item["originalFileName"] as? String
            let type = item["type"] as? String
            let trashed = (item["isTrashed"] as? Bool) ?? (item["isDeleted"] as? Bool) ?? false
            let createdAt = parseAssetDate(from: item)
            return AssetSummary(id: id, originalFileName: name, type: type, isTrashed: trashed, createdAt: createdAt)
        }
    }

    func parseAssetDate(from item: [String: Any]) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let value = item["fileCreatedAt"] as? String {
            return formatter.date(from: value)
        }
        if let value = item["assetCreatedAt"] as? String {
            return formatter.date(from: value)
        }
        if let value = item["createdAt"] as? String {
            return formatter.date(from: value)
        }
        return nil
    }

    func makeFilename(for asset: AssetSummary) -> String {
        let fallback = "\(asset.id)"
        guard let name = asset.originalFileName, !name.isEmpty else {
            return fallback
        }
        let sanitized = sanitizeFilename(name)
        return "\(asset.id)-\(sanitized)"
    }

    func sanitizeFilename(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\")
        return name.components(separatedBy: forbidden).joined(separator: "_")
    }

    func destinationURL(for asset: AssetSummary, baseFolder: URL) -> URL {
        let filename = makeFilename(for: asset)
        let folder: URL
        switch downloadFolderStructure {
        case "year":
            folder = datedFolder(baseFolder: baseFolder, assetDate: asset.createdAt, format: "yyyy")
        case "year-month":
            folder = datedFolder(baseFolder: baseFolder, assetDate: asset.createdAt, format: "yyyy/MM")
        default:
            folder = baseFolder
        }
        return folder.appendingPathComponent(filename)
    }

    func datedFolder(baseFolder: URL, assetDate: Date?, format: String) -> URL {
        let date = assetDate ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = format
        let path = formatter.string(from: date)
        let folder = baseFolder.appendingPathComponent(path, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func writeSidecarMetadata(baseURL: URL, assetID: String, destinationURL: URL) async throws {
        let url = baseURL.appendingPathComponent("assets/\(assetID)/metadata")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response, data: data)

        let sidecarURL = URL(fileURLWithPath: destinationURL.path + ".immich.json")
        try data.write(to: sidecarURL, options: [.atomic])
    }

    func updateProgress(downloaded: Int, skipped: Int, total: Int?) async {
        await MainActor.run {
            if let total {
                progressValue = min(1, Double(downloaded + skipped) / Double(max(total, 1)))
                progressText = "Downloaded \(downloaded), skipped \(skipped) of \(total)"
            } else {
                progressValue = 0
                progressText = "Downloaded \(downloaded), skipped \(skipped)"
            }
            speedText = currentSpeedText()
            appendDownloadSample()
        }
    }

    func currentSpeedText() -> String {
        guard let start = downloadStartDate else { return "" }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return "" }
        let mb = Double(bytesDownloaded) / 1_048_576
        let rate = mb / elapsed
        return String(format: "Speed: %.2f MB/s", rate)
    }

    func currentSpeedValue() -> Double {
        guard let start = downloadStartDate else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return 0 }
        let mb = Double(bytesDownloaded) / 1_048_576
        return mb / elapsed
    }

    func updateUploadProgress(uploaded: Int, skipped: Int, total: Int) async {
        await MainActor.run {
            if total > 0 {
                uploadProgressText = "Uploaded \(uploaded), skipped \(skipped) of \(total)"
            } else {
                uploadProgressText = "Uploaded \(uploaded), skipped \(skipped)"
            }
            uploadSpeedText = currentUploadSpeedText()
            appendUploadSample()
        }
    }

    func updateUploadQueue(index: Int, status: UploadStatus, error: String?) async {
        await MainActor.run {
            guard uploadQueue.indices.contains(index) else { return }
            uploadQueue[index].status = status
            uploadQueue[index].error = error
        }
    }

    func currentUploadSpeedText() -> String {
        guard let start = uploadStartDate else { return "" }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return "" }
        let mb = Double(bytesUploaded) / 1_048_576
        let rate = mb / elapsed
        return String(format: "Upload: %.2f MB/s", rate)
    }

    func currentUploadSpeedValue() -> Double {
        guard let start = uploadStartDate else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return 0 }
        let mb = Double(bytesUploaded) / 1_048_576
        return mb / elapsed
    }

    func appendDownloadSample() {
        let value = currentSpeedValue()
        if downloadSpeedSamples.count >= 60 {
            downloadSpeedSamples.removeFirst()
        }
        downloadSpeedSamples.append(value)
    }

    func appendUploadSample() {
        let value = currentUploadSpeedValue()
        if uploadSpeedSamples.count >= 60 {
            uploadSpeedSamples.removeFirst()
        }
        uploadSpeedSamples.append(value)
    }

    func setError(_ message: String) async {
        await MainActor.run {
            lastError = message
            progressText = ""
            speedText = ""
        }
    }

    func setUploadError(_ message: String) async {
        await MainActor.run {
            lastError = message
            uploadProgressText = ""
            uploadSpeedText = ""
        }
    }

    func loadAlbums() async {
        let trimmedServer = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedServer.isEmpty else { return }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let baseURL = normalizedBaseURL(from: trimmedServer)
        let url = baseURL.appendingPathComponent("albums")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        do {
            let (data, response) = try await urlSession.data(for: request)
            try validateResponse(response, data: data)
            let parsed = parseAlbums(from: data)
            await MainActor.run {
                albums = parsed.sorted { $0.name.lowercased() < $1.name.lowercased() }
            }
        } catch {
            await MainActor.run {
                lastError = "Album load failed: \(error.localizedDescription)"
            }
        }
    }

    func parseAlbums(from data: Data) -> [Album] {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let array = json as? [[String: Any]] else {
            return []
        }

        return array.compactMap { item -> Album? in
            guard let id = item["id"] as? String else { return nil }
            let name = item["albumName"] as? String ?? item["name"] as? String ?? "Untitled"
            let count = item["assetCount"] as? Int ?? 0
            return Album(id: id, name: name, assetCount: count)
        }
    }

    func loadServerVersion() async {
        let trimmedServer = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedServer.isEmpty else { return }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let baseURL = normalizedBaseURL(from: trimmedServer)
        let url = baseURL.appendingPathComponent("server/version")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        do {
            let (data, response) = try await urlSession.data(for: request)
            try validateResponse(response, data: data)
            let version = parseServerVersion(from: data)
            await MainActor.run {
                serverVersion = version
            }
        } catch {
            await MainActor.run {
                serverVersion = ""
            }
        }
    }

    func parseServerVersion(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []),
           let dict = json as? [String: Any] {
            if let version = dict["version"] as? String { return version }
            if let server = dict["serverVersion"] as? String { return server }
            if let major = dict["major"] as? Int,
               let minor = dict["minor"] as? Int,
               let patch = dict["patch"] as? Int {
                return "\(major).\(minor).\(patch)"
            }
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    func loadDuplicates() async {
        let trimmedServer = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedServer.isEmpty else { return }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let baseURL = normalizedBaseURL(from: trimmedServer)
        let url = baseURL.appendingPathComponent("duplicates")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        do {
            let (data, response) = try await urlSession.data(for: request)
            try validateResponse(response, data: data)
            let result = parseDuplicates(from: data)
            await MainActor.run {
                duplicateGroupsCount = result.groups
                duplicatesCount = result.items
                duplicatesLastChecked = Date()
            }
        } catch {
            await MainActor.run {
                duplicateGroupsCount = 0
                duplicatesCount = 0
                duplicatesLastChecked = Date()
            }
        }
    }

    func parseDuplicates(from data: Data) -> (groups: Int, items: Int) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return (0, 0)
        }

        if let array = json as? [[String: Any]] {
            let groups = array.count
            let items = array.reduce(0) { partial, item in
                if let assets = item["assets"] as? [[String: Any]] {
                    return partial + assets.count
                }
                if let assetIds = item["assetIds"] as? [String] {
                    return partial + assetIds.count
                }
                return partial
            }
            return (groups, items)
        }

        if let array = json as? [[Any]] {
            let groups = array.count
            let items = array.reduce(0) { $0 + $1.count }
            return (groups, items)
        }

        return (0, 0)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
