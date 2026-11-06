import Foundation
import CoreData
import os

class PersistenceController {
    static let shared = PersistenceController()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app",
        category: "PersistenceController"
    )
    
    let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    init(inMemory: Bool = false) {
        let persistentContainer = NSPersistentContainer(name: "LiteLog")
        container = persistentContainer

        if let storeDescription = persistentContainer.persistentStoreDescriptions.first {
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            storeDescription.shouldAddStoreAsynchronously = false

            if inMemory {
                storeDescription.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        var recoveryAttempted = false
        persistentContainer.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                Self.logger.error("Failed to load Core Data store: \(error), \(error.userInfo)")

                guard !inMemory, !recoveryAttempted else {
                    return
                }
                recoveryAttempted = true

                if Self.preserveUnreadableStore(description: storeDescription) {
                    DispatchQueue.main.async {
                        persistentContainer.loadPersistentStores { _, retryError in
                            if let retryError {
                                Self.logger.error("Failed to recreate Core Data store: \(retryError.localizedDescription)")
                            } else {
                                Self.logger.info("Recreated an empty Core Data store after preserving the unreadable store")
                            }
                        }
                    }
                }
            }
        }

        persistentContainer.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        persistentContainer.viewContext.undoManager = nil
    }
    
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                Self.logger.error("Failed to save Core Data context: \(error.localizedDescription)")
                context.rollback()
            }
        }
    }

    private static func preserveUnreadableStore(description: NSPersistentStoreDescription) -> Bool {
        guard let storeURL = description.url else {
            return false
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return true
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let recoveryDirectory = storeURL.deletingLastPathComponent()
            .appendingPathComponent("Recovery-\(timestamp)", isDirectory: true)
        let suffixes = ["", "-wal", "-shm"]

        do {
            try fileManager.createDirectory(
                at: recoveryDirectory,
                withIntermediateDirectories: true
            )

            for suffix in suffixes {
                let source = URL(fileURLWithPath: storeURL.path + suffix)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                let destination = recoveryDirectory.appendingPathComponent(source.lastPathComponent)
                try fileManager.moveItem(at: source, to: destination)
            }
            return true
        } catch {
            logger.error("Failed to preserve unreadable Core Data store: \(error.localizedDescription)")
            return false
        }
    }
}
