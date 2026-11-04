import CloudKit
import SwiftUI

/// One "backup" record in the user's private CloudKit database holding the game state and trek history.
enum CloudBackup {
    struct Info {
        let savedAt: Date
        let device: String
    }

    enum Failure: LocalizedError {
        case noAccount, nothingToRestore
        var errorDescription: String? {
            switch self {
            case .noAccount: loc("Sign in to iCloud in Settings to use backups.")
            case .nothingToRestore: loc("No iCloud backup found.")
            }
        }
    }

    private static let container = CKContainer(identifier: "iCloud.id.gian.meowtrek")
    private static var db: CKDatabase { container.privateCloudDatabase }
    private static let recordID = CKRecord.ID(recordName: "backup")
    private static let lastKey = "backup.last"

    static var lastBackup: Date? { UserDefaults.standard.object(forKey: lastKey) as? Date }

    static func accountReady() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    static func latest() async -> Info? {
        guard await accountReady(), let r = try? await db.record(for: recordID) else { return nil }
        return Info(savedAt: r["savedAt"] as? Date ?? r.modificationDate ?? .distantPast, device: r["device"] as? String ?? "")
    }

    @MainActor
    static func backup(_ state: AppState) async throws {
        guard await accountReady() else { throw Failure.noAccount }
        let dir = FileManager.default.temporaryDirectory.appending(path: "backup-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let files: [(String, Data)] = [("state", state.backupData()), ("treks", state.treks.exportData()), ("meals", state.meals.exportData())]
        let record = (try? await db.record(for: recordID)) ?? CKRecord(recordType: "Backup", recordID: recordID)
        for (name, data) in files {
            let url = dir.appending(path: "\(name).json")
            try data.write(to: url)
            record[name] = CKAsset(fileURL: url)
        }
        record["savedAt"] = Date.now as CKRecordValue
        record["device"] = UIDevice.current.name as CKRecordValue
        _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        UserDefaults.standard.set(Date.now, forKey: lastKey)
        Telemetry.track("backup_done")
    }

    @MainActor
    static func restore(_ state: AppState) async throws {
        guard await accountReady() else { throw Failure.noAccount }
        guard let r = try? await db.record(for: recordID),
              let stateURL = (r["state"] as? CKAsset)?.fileURL,
              let data = try? Data(contentsOf: stateURL) else { throw Failure.nothingToRestore }
        try state.restoreBackup(data)
        if let url = (r["treks"] as? CKAsset)?.fileURL, let d = try? Data(contentsOf: url) { state.treks.replace(with: d) }
        if let url = (r["meals"] as? CKAsset)?.fileURL, let d = try? Data(contentsOf: url) { state.meals.replace(with: d) }
    }

    /// Plus members get a quiet backup at most once a day when the app comes to the foreground.
    @MainActor
    static func autoBackupIfDue(_ state: AppState) async {
        guard state.isPlus, state.onboarded else { return }
        if let last = lastBackup, Date.now.timeIntervalSince(last) < 20 * 3600 { return }
        try? await backup(state)
    }
}

struct BackupSection: View {
    @Environment(AppState.self) private var state
    @State private var info: CloudBackup.Info?
    @State private var busy = false
    @State private var confirmRestore = false
    @State private var showPaywall = false

    var body: some View {
        Group {
            LabeledContent(loc("Last backup"), value: info.map { $0.savedAt.formatted(.relative(presentation: .named)) } ?? loc("Never"))
            Button {
                guard state.isPlus else { showPaywall = true; return }
                run { try await CloudBackup.backup(state); state.show(loc("Backed up to iCloud"), art: "deco_cloud") }
            } label: {
                HStack {
                    Text("Back up now")
                    Spacer()
                    if !state.isPlus { Tag(text: "Plus", color: .sun, textColor: .ink) }
                }
            }
            Button("Restore from iCloud") { confirmRestore = true }
                .disabled(info == nil)
        }
        .disabled(busy)
        .task { info = await CloudBackup.latest() }
        .confirmationDialog("Restore from iCloud?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restore", role: .destructive) {
                run { try await CloudBackup.restore(state); state.show(loc("Restored from iCloud"), art: "deco_cloud") }
            }
        } message: {
            Text("Your coins, items, looks, friends, treks and quests on this iPhone will be replaced by the backup.")
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true
        Task {
            do { try await work() } catch { state.show(error.localizedDescription) }
            info = await CloudBackup.latest()
            busy = false
        }
    }
}
