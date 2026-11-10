import SwiftData
import SwiftUI

@main
struct LiftingTrackerApp: App {
    private let container: ModelContainer

    init() {
        AppFont.registerBundledFonts()

        // The UI test runs against an empty in-memory store with one sample workout.
        let uiTesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let schema = Schema(AppSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: uiTesting)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
        if uiTesting {
            SampleData.seed(container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
