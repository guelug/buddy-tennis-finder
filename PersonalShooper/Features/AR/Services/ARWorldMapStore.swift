import Foundation
import ARKit

/// Persists the ARKit world map to disk so saved garment locations survive across sessions.
///
/// AR world coordinates reset every time a new session starts, so a raw saved position is
/// meaningless on its own. By re-loading the world map as the session's `initialWorldMap`, ARKit
/// relocalizes the user into the same coordinate space (once they point the camera at the same
/// area), and the saved positions line up with the real world again.
enum ARWorldMapStore {
    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("closet_world_map.arworldmap")
    }

    static var hasSavedMap: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func save(_ worldMap: ARWorldMap) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true) else {
            return
        }
        try? data.write(to: fileURL, options: [.atomic])
    }

    static func load() -> ARWorldMap? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
