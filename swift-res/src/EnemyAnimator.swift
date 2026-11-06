import SpriteKit

final class EnemyAnimator {
    private let node: SKSpriteNode
    private var textures: [SKTexture] = []
    private var time: CGFloat = 0

    init(node: SKSpriteNode) {
        self.node = node
        for column in 0..<2 {
            if let texture = SpriteSheet.texture(
                named: "enemysheet",
                cellSize: CGSize(width: 16, height: 16),
                column: column,
                row: 2
            ) {
                textures.append(texture)
            }
        }
    }

    func update(dt: CGFloat, direction: CGFloat, onGround: Bool) {
        guard textures.count >= 2 else { return }

        node.xScale = direction < 0 ? -1 : 1
        time += dt
        let frame = onGround ? Int(time / 0.14) % 2 : 0
        node.texture = textures[frame]
    }
}
