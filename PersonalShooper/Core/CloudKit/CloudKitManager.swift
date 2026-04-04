import CloudKit
import SwiftUI

// MARK: - CloudKit Record Types
enum CloudKitRecord {
    static let userCredits = "UserCredits"
    static let userProfile = "UserProfile"
    static let clothingItem = "ClothingItem"
}

// MARK: - User Credits Record
struct UserCreditsRecord {
    var remainingTryOnCredits: Int
    var totalUsedThisMonth: Int
    var currentTier: String
    var lastResetDate: Date
    var receiptHash: String

    init(
        remainingTryOnCredits: Int = 5,
        totalUsedThisMonth: Int = 0,
        currentTier: String = "free",
        lastResetDate: Date = Date(),
        receiptHash: String = ""
    ) {
        self.remainingTryOnCredits = remainingTryOnCredits
        self.totalUsedThisMonth = totalUsedThisMonth
        self.currentTier = currentTier
        self.lastResetDate = lastResetDate
        self.receiptHash = receiptHash
    }

    static let freeTierDefault = UserCreditsRecord()
}

// MARK: - Storage Quota Status
enum StorageQuotaStatus {
    case ok(used: Int64, total: Int64)
    case warning(used: Int64, total: Int64)
    case critical(used: Int64, total: Int64)
}

// MARK: - CloudKit Error
enum CloudKitError: LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case quotaExceeded
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to iCloud to sync your data."
        case .networkUnavailable:
            return "Network unavailable. Your data will sync when connected."
        case .quotaExceeded:
            return "iCloud storage quota exceeded."
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - CloudKit Manager
@MainActor
final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    @Published var isSyncEnabled: Bool = true
    @Published var lastSyncDate: Date?
    @Published var iCloudAvailable: Bool = false

    private let freeTierMaxItems: Int = 100

    private init() {
        container = CKContainer(identifier: "iCloud.com.personalshooper.app")
        privateDatabase = container.privateCloudDatabase
        Task {
            await checkAccountStatus()
        }
    }

    // MARK: - Account Status

    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            iCloudAvailable = (status == .available)
        } catch {
            iCloudAvailable = false
        }
    }

    // MARK: - UserCredits

    func fetchCredits() async throws -> UserCreditsRecord {
        guard iCloudAvailable else {
            throw CloudKitError.networkUnavailable
        }

        let predicate = NSPredicate(format: "recordName == %@", "userCredits")
        let query = CKQuery(recordType: CloudKitRecord.userCredits, predicate: predicate)

        do {
            let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: 1)
            if let (_, result) = results.first, case .success(let record) = result {
                return recordToUserCredits(record)
            }
        } catch {
            // If fetch fails, return defaults
        }

        return UserCreditsRecord.freeTierDefault
    }

    func saveCredits(_ credits: UserCreditsRecord) async throws {
        guard iCloudAvailable else {
            throw CloudKitError.networkUnavailable
        }

        let recordID = CKRecord.ID(recordName: "userCredits")
        let record = CKRecord(recordType: CloudKitRecord.userCredits, recordID: recordID)

        record["remainingTryOnCredits"] = credits.remainingTryOnCredits as NSNumber
        record["totalUsedThisMonth"] = credits.totalUsedThisMonth as NSNumber
        record["currentTier"] = credits.currentTier
        record["lastResetDate"] = credits.lastResetDate
        record["receiptHash"] = credits.receiptHash

        _ = try await privateDatabase.save(record)
        lastSyncDate = Date()
    }

    func decrementCredits(by amount: Int) async throws {
        var credits = try await fetchCredits()
        credits.remainingTryOnCredits = max(0, credits.remainingTryOnCredits - amount)
        credits.totalUsedThisMonth += amount
        try await saveCredits(credits)
    }

    func resetMonthlyCredits() async throws {
        var credits = try await fetchCredits()
        credits.remainingTryOnCredits = credits.currentTier == "free" ? 5 : (credits.currentTier == "premium" ? 50 : 200)
        credits.totalUsedThisMonth = 0
        credits.lastResetDate = Date()
        try await saveCredits(credits)
    }

    func syncCreditsWithVercel(receiptHash: String) async throws {
        // Placeholder for Vercel sync
        // In production, this would call the /api/sync-credits endpoint
    }

    // MARK: - Clothing Items

    func saveClothingItem(_ item: ClothingItem) async throws {
        guard iCloudAvailable else {
            throw CloudKitError.networkUnavailable
        }

        let record = clothingItemToRecord(item)
        _ = try await privateDatabase.save(record)
        lastSyncDate = Date()
    }

    func fetchClothingItems(limit: Int = 100) async throws -> [ClothingItem] {
        guard iCloudAvailable else {
            throw CloudKitError.networkUnavailable
        }

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: CloudKitRecord.clothingItem, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        do {
            let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: limit)
            return results.compactMap { _, result -> ClothingItem? in
                guard case .success(let record) = result else { return nil }
                return recordToClothingItem(record)
            }
        } catch {
            throw mapCloudKitError(error)
        }
    }

    func deleteClothingItem(id: String) async throws {
        guard iCloudAvailable else {
            throw CloudKitError.networkUnavailable
        }

        let recordID = CKRecord.ID(recordName: id)
        try await privateDatabase.deleteRecord(withID: recordID)
        lastSyncDate = Date()
    }

    func clothingItemCount() async throws -> Int {
        guard iCloudAvailable else {
            return 0
        }

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: CloudKitRecord.clothingItem, predicate: predicate)

        do {
            let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: 100)
            return results.count
        } catch {
            return 0
        }
    }

    // MARK: - Delete All Records

    func deleteAllRecords() async throws {
        guard iCloudAvailable else {
            throw CloudKitError.networkUnavailable
        }

        let recordTypes = [CloudKitRecord.userCredits, CloudKitRecord.userProfile, CloudKitRecord.clothingItem]

        for recordType in recordTypes {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

            do {
                let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: 100)
                for (recordID, result) in results {
                    if case .success = result {
                        try await privateDatabase.deleteRecord(withID: recordID)
                    }
                }
            } catch {
                // Continue with next record type
                continue
            }
        }

        lastSyncDate = Date()
    }

    // MARK: - Storage Quota

    func checkStorageQuota() async throws -> StorageQuotaStatus {
        // CloudKit doesn't provide direct quota APIs
        // Return a placeholder
        return .ok(used: 0, total: 2_000_000_000)
    }

    // MARK: - Helper Methods

    private func recordToUserCredits(_ record: CKRecord) -> UserCreditsRecord {
        UserCreditsRecord(
            remainingTryOnCredits: (record["remainingTryOnCredits"] as? NSNumber)?.intValue ?? 5,
            totalUsedThisMonth: (record["totalUsedThisMonth"] as? NSNumber)?.intValue ?? 0,
            currentTier: record["currentTier"] as? String ?? "free",
            lastResetDate: record["lastResetDate"] as? Date ?? Date(),
            receiptHash: record["receiptHash"] as? String ?? ""
        )
    }

    private func clothingItemToRecord(_ item: ClothingItem) -> CKRecord {
        let record = CKRecord(recordType: CloudKitRecord.clothingItem)
        record["id"] = item.id.uuidString
        record["name"] = item.name
        record["category"] = item.category.rawValue
        record["createdAt"] = item.createdAt
        return record
    }

    private func recordToClothingItem(_ record: CKRecord) -> ClothingItem? {
        // This is a placeholder - actual conversion should happen via SwiftData
        // CloudKit records contain minimal data, the full ClothingItem comes from local SwiftData
        guard let name = record["name"] as? String,
              let categoryString = record["category"] as? String,
              let category = ClothingCategory(rawValue: categoryString) else {
            return nil
        }

        // Create a temporary item with the record ID for reference
        let item = ClothingItem(
            name: name,
            category: category
        )
        return item
    }

    private func mapCloudKitError(_ error: Error) -> CloudKitError {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return .notAuthenticated
            case .networkUnavailable, .networkFailure:
                return .networkUnavailable
            case .quotaExceeded:
                return .quotaExceeded
            default:
                return .serverError(ckError.localizedDescription)
            }
        }
        return .serverError(error.localizedDescription)
    }
}
