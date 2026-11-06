import SpriteKit

final class MarioAnimator {
    private let node: SKSpriteNode
    private var textures: [SKTexture] = []
    private var previousX: CGFloat
    private var runTime: CGFloat = 0

    init(node: SKSpriteNode) {
        self.node = node
        self.previousX = node.position.x

        for column in 0..<15 {
            if let texture = SpriteSheet.texture(
                named: "mariosheet",
                cellSize: CGSize(width: 32, height: 32),
                column: column,
                row: 0
            ) {
                textures.append(texture)
            }
        }
    }

    func update(dt: CGFloat, velocityX: CGFloat = 0, velocityY: CGFloat = 0, onGround: Bool = true) {
        guard !textures.isEmpty else { return }

        let dx = node.position.x - previousX
        previousX = node.position.x
        if dx < -0.1 { node.xScale = -1 }
        else if dx > 0.1 { node.xScale = 1 }

        // Mario.java: runTime += abs(xa) + 5; frame = (runTime / 20) % 4.
        if abs(velocityX) < 0.5 {
            runTime = 0
        } else {
            runTime += abs(velocityX) + 5
        }

        var frame = Int(runTime / 20) % 4
        if frame == 3 { frame = 1 }
        if abs(velocityX) > 10 { frame += 3 }

        if !onGround {
            frame = abs(velocityX) > 10 ? 7 : 6
        }
        node.texture = textures[min(frame, textures.count - 1)]
    }
}
