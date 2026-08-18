import Foundation

enum StoreFileRecovery {
    @discardableResult
    static func backupAndRemoveStore(
        storeURL: URL,
        backupRoot: URL,
        fileManager: FileManager = .default
    ) throws -> URL? {
        let storeFiles = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ].filter { fileManager.fileExists(atPath: $0.path) }

        guard !storeFiles.isEmpty else { return nil }

        let backupDirectory = backupRoot
            .appending(path: ISO8601DateFormatter().string(from: Date()), directoryHint: .isDirectory)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        for file in storeFiles {
            try fileManager.copyItem(at: file, to: backupDirectory.appending(path: file.lastPathComponent))
        }
        for file in storeFiles {
            try fileManager.removeItem(at: file)
        }
        return backupDirectory
    }
}
