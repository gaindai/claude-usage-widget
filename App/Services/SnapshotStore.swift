import Foundation

/// Schreibt den aggregierten Snapshot atomar nach
/// ~/Library/Application Support/ClaudeUsage/snapshot.json (0600).
/// Die Widget-Extension liest genau diese eine Datei read-only.
enum SnapshotStore {
    static func write(_ snapshot: UsageSnapshot) throws {
        let dir = SnapshotLocation.directoryURL
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let data = try SnapshotLocation.makeEncoder().encode(snapshot)
        let url = SnapshotLocation.fileURL
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
