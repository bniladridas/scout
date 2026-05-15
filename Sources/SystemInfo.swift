import Foundation

struct SystemInfo {
    let productName: String
    let productVersion: String
    let buildVersion: String

    var displayName: String {
        "\(productName) \(productVersion) (\(buildVersion))"
    }

    static var current: SystemInfo {
        let values = swVersValues()
        return SystemInfo(
            productName: values["ProductName"] ?? "macOS",
            productVersion: values["ProductVersion"] ?? processInfoVersion,
            buildVersion: values["BuildVersion"] ?? "unknown build"
        )
    }

    private static var processInfoVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private static func swVersValues() -> [String: String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sw_vers")

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return [:]
        }

        guard process.terminationStatus == 0 else { return [:] }

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: output, encoding: .utf8) else { return [:] }

        return Dictionary(uniqueKeysWithValues: text.components(separatedBy: .newlines).compactMap { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return (
                String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines),
                String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        })
    }
}
