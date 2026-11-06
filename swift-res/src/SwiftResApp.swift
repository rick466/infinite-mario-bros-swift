import SwiftUI

@main
struct SwiftResApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
        }
    }
}
