import Foundation

struct CandidateClassifier: Sendable {
    func shouldMeasureDirectory(url: URL, root: URL) -> Bool {
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let relative = path.hasPrefix(home) ? String(path.dropFirst(home.count)) : path
        let name = url.lastPathComponent

        if isVisibleShallowDirectory(url: url, root: root) {
            return true
        }

        if relative.contains("/.Trash") { return true }
        if name == "target" || relative.contains("/target/debug") || relative.contains("/target/release") { return true }
        if relative == "/Library/Caches" || relative.contains("/Library/Caches/") { return true }
        if relative.contains("/stremio-cache") { return true }
        if relative == "/.npm" || relative.contains("/.npm/") { return true }
        if relative == "/.pub-cache" || relative.contains("/.pub-cache/") { return true }
        if relative.contains("/.cargo/registry") { return true }
        if relative.contains("/.ollama/models") { return true }
        if relative.contains("/.ghcup") { return true }
        if relative.contains("/.rustup/toolchains") { return true }
        if relative.contains("/.elan/toolchains") { return true }
        if relative.contains("/flutter/bin/cache") { return true }
        if name == "node_modules" { return true }

        return false
    }

    private func isVisibleShallowDirectory(url: URL, root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath), path != rootPath else { return false }

        let remainder = path.dropFirst(rootPath.count).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !remainder.isEmpty else { return false }

        let parts = remainder.split(separator: "/")
        guard parts.count <= 2 else { return false }

        let name = url.lastPathComponent
        if name.hasPrefix(".") { return false }
        if name == "Applications" || name == "Library" { return false }
        if name == "Contents" || name == "Resources" || name == "MacOS" { return false }

        return true
    }

    func classify(url: URL, bytes: Int64, isDirectory: Bool) -> CleanupCandidate? {
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let relative = path.hasPrefix(home) ? String(path.dropFirst(home.count)) : path

        if relative.contains("/.Trash") {
            return candidate(url, bytes, "Trash", .safe, "Trash contents can usually be emptied after review.")
        }

        if relative.hasSuffix("/target") || relative.contains("/target/debug") || relative.contains("/target/release") {
            return candidate(url, bytes, "Rust build output", .safe, "Cargo build artifacts. They are recreated by the next build.")
        }

        if relative.contains("/Library/Caches/") || relative == "/Library/Caches" {
            return classifyCache(url: url, bytes: bytes, relative: relative)
        }

        if relative.contains("/stremio-cache") {
            return candidate(url, bytes, "Streaming cache", .safe, "Stremio cache. Remove when cached videos are not needed.")
        }

        if relative.contains("/.npm") {
            return candidate(url, bytes, "npm cache", .likelySafe, "npm and npx cache. Packages may be downloaded again later.")
        }

        if relative.contains("/.pub-cache") {
            return candidate(url, bytes, "Dart/Flutter package cache", .likelySafe, "Downloaded pub packages. Flutter/Dart projects may redownload them.")
        }

        if relative.contains("/.cargo/registry") {
            return candidate(url, bytes, "Rust crate cache", .likelySafe, "Downloaded crate sources and archives. Cargo can fetch them again.")
        }

        if relative.contains("/.ollama/models") {
            return candidate(url, bytes, "Ollama model", .confirm, "Local AI model data. Delete only models you no longer use.")
        }

        if relative.contains("/.ghcup") {
            return candidate(url, bytes, "Haskell toolchain", .confirm, "GHCup-managed compilers and tools. Keep versions you still use.")
        }

        if relative.contains("/.rustup/toolchains") {
            return candidate(url, bytes, "Rust toolchain", .confirm, "Installed Rust toolchains. Remove only unused toolchain versions.")
        }

        if relative.contains("/.elan/toolchains") {
            return candidate(url, bytes, "Lean toolchain", .confirm, "Installed Lean toolchains. Remove only unused versions.")
        }

        if relative.contains("/flutter/bin/cache") {
            return candidate(url, bytes, "Flutter cache", .confirm, "Flutter SDK artifacts. Flutter can recreate them, but downloads may be large.")
        }

        if relative.contains("/node_modules") {
            return candidate(url, bytes, "Node dependencies", .likelySafe, "Project dependencies. Reinstall with the project package manager.")
        }

        if isDirectory, bytes >= 1_000_000_000 {
            return candidate(url, bytes, "Heavy folder", .confirm, "Review this folder before moving it to Trash.")
        }

        if !isDirectory, bytes >= 500_000_000 {
            return candidate(url, bytes, "Heavy file", .confirm, "Review this file before moving it to Trash.")
        }

        return nil
    }

    private func classifyCache(url: URL, bytes: Int64, relative: String) -> CleanupCandidate {
        if relative.contains("/bazel") {
            return candidate(url, bytes, "Bazel cache", .safe, "Build cache. Bazel will rebuild what it needs.")
        }

        if relative.contains("/com.spotify.client") {
            return candidate(url, bytes, "Spotify cache", .safe, "Playback cache. Spotify may recreate it.")
        }

        if relative.contains("/ms-playwright") {
            return candidate(url, bytes, "Playwright browsers", .likelySafe, "Downloaded test browsers. Playwright can install them again.")
        }

        return candidate(url, bytes, "App cache", .likelySafe, "Application cache. Apps usually recreate cache data.")
    }

    private func candidate(_ url: URL, _ bytes: Int64, _ category: String, _ safety: CleanupSafety, _ note: String) -> CleanupCandidate {
        CleanupCandidate(url: url, bytes: bytes, category: category, safety: safety, note: note)
    }
}
