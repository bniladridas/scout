import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = DiskScanner()
    @State private var selectedCandidateID: CleanupCandidate.ID?
    @State private var safetyFilter: CleanupSafety?
    @State private var deleteCandidate: CleanupCandidate?
    @State private var deleteError: String?
    @State private var isMovingToTrash = false
    private let systemInfo = SystemInfo.current

    private var filteredCandidates: [CleanupCandidate] {
        guard let safetyFilter else { return scanner.candidates }
        return scanner.candidates.filter { $0.safety == safetyFilter }
    }

    private var selectedCandidate: CleanupCandidate? {
        guard let selectedCandidateID else { return nil }
        return scanner.candidates.first { $0.id == selectedCandidateID }
    }

    private var safeCount: Int {
        scanner.candidates.filter { $0.safety == .safe }.count
    }

    private var likelySafeCount: Int {
        scanner.candidates.filter { $0.safety == .likelySafe }.count
    }

    private var confirmCount: Int {
        scanner.candidates.filter { $0.safety == .confirm }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            HSplitView {
                table
                    .frame(minWidth: 820, maxWidth: .infinity)
                
                detail
                    .frame(minWidth: 300, idealWidth: 380, maxWidth: 560)
            }
        }
        .onAppear {
            scanner.scanHome()
        }
        .alert(
            "Move this item to Trash?",
            isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }),
            presenting: deleteCandidate
        ) { candidate in
            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
            Button("Move to Trash", role: .destructive) {
                moveToTrash(candidate)
            }
        } message: { candidate in
            Text("\(candidate.formattedSize) at \(candidate.path)")
        }
        .alert("Could Not Move to Trash", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "Unknown error")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Scout")
                    .font(.headline)
                Text(systemInfo.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(scanner.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if scanner.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            }

            Picker("Safety", selection: $safetyFilter) {
                Text("All \(scanner.candidates.count)").tag(Optional<CleanupSafety>.none)
                Text("Safe \(safeCount)").tag(Optional(CleanupSafety.safe))
                Text("Likely \(likelySafeCount)").tag(Optional(CleanupSafety.likelySafe))
                Text("Confirm \(confirmCount)").tag(Optional(CleanupSafety.confirm))
            }
            .pickerStyle(.segmented)
            .frame(width: 360)

            Button {
                chooseFolder()
            } label: {
                Label("Choose Folder", systemImage: "folder")
            }

            if scanner.isScanning {
                Button {
                    scanner.cancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    scanner.scanHome()
                } label: {
                    Label("Scan Home", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var table: some View {
        VStack(spacing: 0) {
            ResultHeader()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCandidates) { candidate in
                        ResultRow(
                            candidate: candidate,
                            isSelected: selectedCandidateID == candidate.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCandidateID = candidate.id
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .overlay {
            if scanner.candidates.isEmpty {
                VStack(spacing: 12) {
                    if scanner.isScanning {
                        ProgressView()
                    }
                    Text(scanner.isScanning ? "Finding heavy items..." : "No heavy items found")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let candidate = selectedCandidate {
                Text(candidate.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                LabeledContent("Size", value: candidate.formattedSize)
                LabeledContent("Safety", value: candidate.safety.rawValue)
                LabeledContent("Category", value: candidate.category)

                Divider()

                Text(candidate.note)
                    .foregroundStyle(.secondary)

                Text(candidate.path)
                    .font(.caption)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([candidate.url])
                    } label: {
                        Label("Reveal", systemImage: "magnifyingglass")
                    }

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(candidate.path, forType: .string)
                    } label: {
                        Label("Copy Path", systemImage: "doc.on.doc")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        deleteCandidate = candidate
                    } label: {
                        Label(isMovingToTrash ? "Moving..." : "Move to Trash", systemImage: "trash")
                    }
                    .disabled(isMovingToTrash)
                }
            } else {
                Spacer()
                Text("Select an item.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(22)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK, let url = panel.url {
            scanner.scan(url: url)
        }
    }

    private func moveToTrash(_ candidate: CleanupCandidate) {
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            deleteCandidate = nil
            removeCandidateAndDescendants(candidate)
            return
        }

        isMovingToTrash = true
        deleteCandidate = nil

        NSWorkspace.shared.recycle([candidate.url]) { _, error in
            DispatchQueue.main.async {
                isMovingToTrash = false

                if let error {
                    deleteError = error.localizedDescription
                    return
                }

                removeCandidateAndDescendants(candidate)
            }
        }
    }

    private func removeCandidateAndDescendants(_ candidate: CleanupCandidate) {
        let removedSelectedCandidate = selectedCandidate.map {
            $0.path == candidate.path || $0.path.hasPrefix(candidate.path + "/")
        } ?? false

        scanner.removeCandidates(atOrInside: candidate.path)

        if removedSelectedCandidate {
            selectedCandidateID = nil
        }
    }
}

struct ResultHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Size")
                .frame(width: 84, alignment: .leading)
            Text("Safety")
                .frame(width: 96, alignment: .leading)
            Text("Category")
                .frame(width: 146, alignment: .leading)
            Text("Path")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.35))
    }
}

struct ResultRow: View {
    let candidate: CleanupCandidate
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(candidate.formattedSize)
                .monospacedDigit()
                .frame(width: 84, alignment: .leading)

            SafetyBadge(safety: candidate.safety)
                .frame(width: 96, alignment: .leading)

            Text(candidate.category)
                .frame(width: 146, alignment: .leading)

            Text(candidate.path)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct SafetyBadge: View {
    let safety: CleanupSafety

    var body: some View {
        Text(safety.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch safety {
        case .safe: .green
        case .likelySafe: .blue
        case .confirm: .orange
        }
    }

    private var background: Color {
        foreground.opacity(0.14)
    }
}
