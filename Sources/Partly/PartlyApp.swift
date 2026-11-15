import SwiftUI

enum Release {
    static let version = "1.1"
    static let build = "12"
}

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
