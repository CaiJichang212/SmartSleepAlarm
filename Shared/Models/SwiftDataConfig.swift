import Foundation
import SwiftData

enum SwiftDataConfig {
    static let modelContainer: ModelContainer = {
        let schema = Schema([Alarm.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
    
    static var modelContext: ModelContext {
        modelContainer.mainContext
    }
}
