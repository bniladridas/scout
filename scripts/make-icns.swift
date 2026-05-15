import Foundation

let source = URL(fileURLWithPath: "Assets/Icons/app-icon.png")
let iconset = URL(fileURLWithPath: "Support/AppIcon.iconset")
let output = URL(fileURLWithPath: "Support/Resources/AppIcon.icns")

let sizes: [(String, Int, Int)] = [
    ("icon_16x16.png", 16, 16),
    ("icon_16x16@2x.png", 32, 32),
    ("icon_32x32.png", 32, 32),
    ("icon_32x32@2x.png", 64, 64),
    ("icon_128x128.png", 128, 128),
    ("icon_128x128@2x.png", 256, 256),
    ("icon_256x256.png", 256, 256),
    ("icon_256x256@2x.png", 512, 512),
    ("icon_512x512.png", 512, 512),
    ("icon_512x512@2x.png", 1024, 1024)
]

let entries: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

try FileManager.default.createDirectory(
    at: iconset,
    withIntermediateDirectories: true
)

for (filename, width, height) in sizes {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    task.arguments = [
        "-s", "format", "png",
        "-z", "\(height)", "\(width)",
        source.path,
        "--out",
        iconset.appendingPathComponent(filename).path
    ]
    try task.run()
    task.waitUntilExit()

    guard task.terminationStatus == 0 else {
        throw NSError(
            domain: "MakeICNS",
            code: Int(task.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "Could not create \(filename)"]
        )
    }
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

func appendOSType(_ value: String, to data: inout Data) {
    data.append(value.data(using: .macOSRoman)!)
}

var body = Data()

for (type, filename) in entries {
    let fileURL = iconset.appendingPathComponent(filename)
    let png = try Data(contentsOf: fileURL)

    appendOSType(type, to: &body)
    appendUInt32(UInt32(png.count + 8), to: &body)
    body.append(png)
}

var icns = Data()
appendOSType("icns", to: &icns)
appendUInt32(UInt32(body.count + 8), to: &icns)
icns.append(body)

try FileManager.default.createDirectory(
    at: output.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try icns.write(to: output, options: .atomic)

print("Created \(output.path)")
