import SwiftUI

@main
struct KarabinerPlusApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Karabiner+") {
            ContentView(model: model)
                .frame(minWidth: 1_060, minHeight: 720)
        }
        .defaultSize(width: 1_180, height: 780)
        .windowResizability(.contentMinSize)
    }
}
