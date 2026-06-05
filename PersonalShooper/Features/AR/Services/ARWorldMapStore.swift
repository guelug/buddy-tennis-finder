import Foundation
@preconcurrency import ARKit
import os.log

/// Persists the ARKit world map to disk so saved garment locations survive across sessions.
///
/// AR world coordinates reset every time a new session starts, so a raw saved position is
/// meaningless on its own. By re-loading the world map as the session's `initialWorldMap`, ARKit
/// relocalizes the user into the same coordinate space (once they point the camera at the same
/// area), and the saved positions line up with the real world again.
enum ARWorldMapStore {
    private static let log = Logger(subsystem: "com.personalshooper.app", category: "ARWorldMapStore")

    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("closet_world_map.arworldmap")
    }

    static var hasSavedMap: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Serialises saves so two concurrent capture completions (place + dismiss) can't corrupt the
    /// file with interleaved writes. Using an actor keeps Swift 6 strict concurrency happy.
    private actor SaveCoordinator {
        private var inFlight = false

        func runSave(_ block: @escaping @Sendable () async -> Void) {
            guard !inFlight else {
                return
            }
            inFlight = true
            Task {
                await block()
                inFlight = false
            }
        }
    }

    private static let coordinator = SaveCoordinator()

    static func save(_ worldMap: ARWorldMap) {
        Task {
            await coordinator.runSave { @Sendable in
                do {
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: worldMap,
                        requiringSecureCoding: true
                    )
                    try data.write(to: fileURL, options: [.atomic])
                    log.info("World map saved: \(data.count, privacy: .public) bytes at \(self.fileURL.path, privacy: .public)")
                } catch {
                    log.error("Failed to save world map: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    static func load() -> ARWorldMap? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
            if map == nil {
                log.error("Saved world map file exists but failed to decode.")
            }
            return map
        } catch {
            log.error("Failed to decode saved world map: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        log.info("Cleared saved world map.")
    }
}
