import Foundation
import CoreData
import SwiftUI
import Combine

class RecordViewModel: ObservableObject {
    private let context: NSManagedObjectContext
    private let settingsManager: SettingsManager
    
    @Published var records: [WeightRecord] = []
    @Published var groupedRecords: [Date: [WeightChangeRecord]] = [:]
    
    var unit: WeightUnit { settingsManager.weightUnit }
    
    init(context: NSManagedObjectContext, settingsManager: SettingsManager) {
        self.context = context
        self.settingsManager = settingsManager
        loadRecords()
    }
    
    func loadRecords() {
        let request = WeightRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.date, ascending: false)]
        request.fetchBatchSize = 20
        request.propertiesToFetch = [
            #keyPath(WeightRecord.date),
            #keyPath(WeightRecord.weight),
            #keyPath(WeightRecord.bodyFatPercentage),
            #keyPath(WeightRecord.waistCircumference),
            #keyPath(WeightRecord.hipCircumference),
            #keyPath(WeightRecord.chestCircumference),
            #keyPath(WeightRecord.thighCircumference),
            #keyPath(WeightRecord.note),
            #keyPath(WeightRecord.imageUrl),
            #keyPath(WeightRecord.measurementTimePeriod)
        ]
        request.returnsObjectsAsFaults = false
        
        do {
            records = try context.fetch(request)
            updateGroupedRecords()
        } catch {
            print("Error fetching records: \(error)")
            records = []
            groupedRecords = [:]
        }
    }
    
    private func updateGroupedRecords() {
        groupedRecords = records.groupedByMonthWithWeightChanges()
    }
    
    func refresh() {
        loadRecords()
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