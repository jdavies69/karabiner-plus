import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(AppModel.Section.allCases, selection: $model.selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.rawValue, systemImage: section.icon)
                }
            }
            .navigationTitle("Karabiner+")
            .listStyle(.sidebar)
        } detail: {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.95)
                    .ignoresSafeArea()

                switch model.selectedSection ?? .start {
                case .start:
                    StartView(model: model)
                case .setup:
                    SetupView(model: model)
                case .coach:
                    CoachView(model: model)
                case .studio:
                    StudioView(model: model)
                case .safety:
                    SafetyView(model: model)
                }
            }
        }
        .background(.regularMaterial)
        .tint(.gray)
    }
}
