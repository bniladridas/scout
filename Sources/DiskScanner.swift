import Foundation

@MainActor
final class DiskScanner: ObservableObject {
    @Published var candidates: [CleanupCandidate] = []
    @Published var isScanning = false
    @Published var status = "Ready"
    @Published var scannedCount = 0

    private let classifier = CandidateClassifier()
    private var scanTask: Task<Void, Never>?

    func scanHome() {
        scan(url: FileManager.default.homeDirectoryForCurrentUser)
    }

    func scan(url: URL) {
        scanTask?.cancel()
        candidates = []
        scannedCount = 0
        isScanning = true
        status = "Scanning \(url.path)"

        scanTask = Task.detached(priority: .userInitiated) { [classifier] in
            var results: [CleanupCandidate] = []
            var seen = Set<String>()
            let scanner = DirectoryWalker(classifier: classifier)

            for await update in scanner.scan(root: url) {
                if Task.isCancelled { return }

                switch update {
                case .progress(let count):
                    await MainActor.run {
                        self.scannedCount = count
                        self.status = "Scanned \(count.formatted()) items"
                    }
                case .candidate(let candidate):
                    if seen.insert(candidate.path).inserted {
                        results.append(candidate)
                        results.sort {
                            if $0.bytes == $1.bytes { return $0.path < $1.path }
                            return $0.bytes > $1.bytes
                        }

                        let snapshot = Array(results.prefix(200))
                        await MainActor.run {
                            self.candidates = snapshot
                        }
                    }
                case .finished(let count):
                    let finalResults = Array(results.sorted {
                        if $0.bytes == $1.bytes { return $0.path < $1.path }
                        return $0.bytes > $1.bytes
                    }.prefix(200))

                    await MainActor.run {
                        self.candidates = finalResults
                        self.scannedCount = count
                        self.status = "Found \(finalResults.count) heavy items."
                        self.isScanning = false
                    }
                }
            }
        }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        status = "Cancelled"
    }

    func removeCandidate(id: CleanupCandidate.ID) {
        candidates.removeAll { $0.id == id }
    }

    func removeCandidates(atOrInside path: String) {
        candidates.removeAll { candidate in
            candidate.path == path || candidate.path.hasPrefix(path + "/")
        }
    }
}

enum ScanUpdate {
    case progress(Int)
    case candidate(CleanupCandidate)
    case finished(Int)
}

struct DirectoryWalker {
    let classifier: CandidateClassifier

    func scan(root: URL) -> AsyncStream<ScanUpdate> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let fileManager = FileManager.default
                var count = 0
                let keys: [URLResourceKey] = [
                    .isDirectoryKey,
                    .isRegularFileKey,
                    .fileSizeKey,
                    .totalFileAllocatedSizeKey,
                    .isSymbolicLinkKey,
                    .isPackageKey
                ]

                guard let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: keys,
                    options: [.skipsPackageDescendants],
                    errorHandler: { _, _ in true }
                ) else {
                    continuation.yield(.finished(0))
                    continuation.finish()
                    return
                }

                while let url = enumerator.nextObject() as? URL {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    count += 1
                    if count % 250 == 0 {
                        continuation.yield(.progress(count))
                    }

                    let values = try? url.resourceValues(forKeys: Set(keys))
                    if values?.isSymbolicLink == true { continue }

                    let isDirectory = values?.isDirectory == true
                    let bytes: Int64

                    if isDirectory {
                        guard classifier.shouldMeasureDirectory(url: url, root: root) else { continue }
                        bytes = Self.allocatedSize(ofDirectory: url, fileManager: fileManager)
                    } else {
                        let allocated = values?.totalFileAllocatedSize
                        let logical = values?.fileSize
                        bytes = Int64(allocated ?? logical ?? 0)
                    }

                    guard bytes > 0 else { continue }

                    if let candidate = classifier.classify(url: url, bytes: bytes, isDirectory: isDirectory) {
                        continuation.yield(.candidate(candidate))
                    }
                }

                continuation.yield(.finished(count))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func allocatedSize(ofDirectory directory: URL, fileManager: FileManager) -> Int64 {
        let keys: [URLResourceKey] = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            if Task.isCancelled { break }
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isSymbolicLink == true { continue }
            if values?.isDirectory == true { continue }
            let allocated = values?.totalFileAllocatedSize
            let logical = values?.fileSize
            total += Int64(allocated ?? logical ?? 0)
        }
        return total
    }
}
