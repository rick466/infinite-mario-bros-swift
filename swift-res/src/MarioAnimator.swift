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

    func update(dt: CGFloat, velocityY: CGFloat = 0, onGround: Bool = true) {
        guard !textures.isEmpty else { return }

        let dx = node.position.x - previousX
        previousX = node.position.x

        let speed = abs(dx) / max(dt, 0.0001)

        if dx < -0.5 {
            node.xScale = -1
        } else if dx > 0.5 {
            node.xScale = 1
        }

        if !onGround {
            let frame = velocityY > 0 ? 6 : 7
            node.texture = textures[min(frame, textures.count - 1)]
            return
        }

        if speed > 8 {
            runTime += dt * speed
            let frame = Int(runTime / 7.5) % 4
            node.texture = textures[min(frame, textures.count - 1)]
        } else {
            node.texture = textures[0]
            runTime = 0
        }
    }
}
