import Foundation

final class UploadIndex {
    private var fileIDs: [String: String] = [:]
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = base?.appendingPathComponent("ImmichSync", isDirectory: true)
        if let dir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("uploaded-assets.json")
        } else {
            fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("uploaded-assets.json")
        }
        load()
    }

    func contains(path: String) -> Bool {
        fileIDs[path] != nil
    }

    func add(path: String, assetID: String) {
        fileIDs[path] = assetID
    }

    func count() -> Int {
        fileIDs.count
    }

    func save() {
        if let data = try? JSONSerialization.data(withJSONObject: fileIDs, options: []) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    func clear() {
        fileIDs.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = json as? [String: String] else {
            return
        }
        fileIDs = dict
    }
}
