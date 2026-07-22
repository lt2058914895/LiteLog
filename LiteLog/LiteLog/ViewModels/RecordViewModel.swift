import Foundation
import CoreData
import SwiftUI
import Combine
import os

class RecordViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    private let context: NSManagedObjectContext
    private let settingsManager: SettingsManager
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app", category: "RecordViewModel")
    
    @Published var records: [WeightRecord] = []
    @Published var groupedRecords: [Date: [WeightChangeRecord]] = [:]
    
    private var fetchedResultsController: NSFetchedResultsController<WeightRecord>?
    
    var unit: WeightUnit { settingsManager.weightUnit }
    
    init(context: NSManagedObjectContext, settingsManager: SettingsManager) {
        self.context = context
        self.settingsManager = settingsManager
        super.init()
        setupFetchedResultsController()
    }
    
    private func setupFetchedResultsController() {
        let request = WeightRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]
        request.fetchBatchSize = 20
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        fetchedResultsController?.delegate = self
        
        do {
            try fetchedResultsController?.performFetch()
            records = fetchedResultsController?.fetchedObjects ?? []
            updateGroupedRecords()
        } catch {
            Self.logger.error("Error fetching records: \(error.localizedDescription)")
            records = []
            groupedRecords = [:]
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        #if DEBUG
        Self.logger.debug("FRC content changed, records count: \(controller.fetchedObjects?.count ?? 0)")
        #endif
        records = controller.fetchedObjects as? [WeightRecord] ?? []
        updateGroupedRecords()
    }
    
    private func updateGroupedRecords() {
        groupedRecords = records.groupedByMonthWithWeightChanges()
    }
    
    func refresh() {
        context.refreshAllObjects()
        do {
            try fetchedResultsController?.performFetch()
            records = fetchedResultsController?.fetchedObjects ?? []
            updateGroupedRecords()
        } catch {
            Self.logger.error("Error refreshing records: \(error.localizedDescription)")
        }
    }
    
    func forceRefresh() {
        objectWillChange.send()
        refresh()
    }
    
    var sortedGroupedRecords: [(Date, [WeightChangeRecord])] {
        groupedRecords.sorted { $0.key > $1.key }
    }
    
    func filteredRecords(with bodyFat: Bool = false, waist: Bool = false) -> [WeightRecord] {
        records.filter { record in
            if bodyFat {
                return record.bodyFatPercentageValue != nil
            }
            if waist {
                return record.waistCircumferenceValue != nil
            }
            return true
        }
    }
    
    func groupedFilteredRecords(with bodyFat: Bool = false, waist: Bool = false) -> [Date: [WeightChangeRecord]] {
        let filtered = filteredRecords(with: bodyFat, waist: waist)
        return filtered.groupedByMonthWithWeightChanges()
    }
    
    var sortedFilteredBodyFatRecords: [(Date, [WeightChangeRecord])] {
        groupedFilteredRecords(with: true).sorted { $0.key > $1.key }
    }
    
    var sortedFilteredWaistRecords: [(Date, [WeightChangeRecord])] {
        groupedFilteredRecords(with: false, waist: true).sorted { $0.key > $1.key }
    }
}