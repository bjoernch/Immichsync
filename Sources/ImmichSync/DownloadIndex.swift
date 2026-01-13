import Foundation

final class DownloadIndex {
    private var assetIDs: Set<String> = []
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = base?.appendingPathComponent("ImmichSync", isDirectory: true)
        if let dir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("downloaded-assets.json")
        } else {
            fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("downloaded-assets.json")
        }
        load()
    }

    func contains(_ id: String) -> Bool {
        assetIDs.contains(id)
    }

    func add(_ id: String) {
        assetIDs.insert(id)
    }

    func count() -> Int {
        assetIDs.count
    }

    func clear() {
        assetIDs.removeAll()
        save()
    }

    func save() {
        let array = Array(assetIDs)
        if let data = try? JSONSerialization.data(withJSONObject: array, options: []) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let array = json as? [String] else {
            return
        }
        assetIDs = Set(array)
    }
}
