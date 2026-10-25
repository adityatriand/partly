import SwiftUI

@main
struct PartlyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Partly") {
            RootView()
                .environmentObject(model)
        }
        .defaultSize(width: 1120, height: 800)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh Jobs") { Task { await model.refresh() } }
                    .keyboardShortcut("r")
                    .disabled(model.refreshing)
            }
        }
    }
}
