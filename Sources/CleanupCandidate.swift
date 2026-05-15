import Foundation

enum CleanupSafety: String, CaseIterable, Comparable {
    case safe = "Safe"
    case likelySafe = "Likely Safe"
    case confirm = "Confirm"

    var rank: Int {
        switch self {
        case .safe: 0
        case .likelySafe: 1
        case .confirm: 2
        }
    }

    static func < (lhs: CleanupSafety, rhs: CleanupSafety) -> Bool {
        lhs.rank < rhs.rank
    }
}

struct CleanupCandidate: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let bytes: Int64
    let category: String
    let safety: CleanupSafety
    let note: String

    var path: String { url.path }
    var name: String { url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent }
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
