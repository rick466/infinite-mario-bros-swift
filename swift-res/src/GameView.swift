import SwiftUI
import SpriteKit

struct GameView: View {
    @State private var gameScene = GameScene()

    var body: some View {
        SpriteView(scene: gameScene)
            .ignoresSafeArea()
            .background(.black)
        }
}
