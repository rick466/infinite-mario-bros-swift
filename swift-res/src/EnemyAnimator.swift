import SpriteKit

final class EnemyAnimator {
    private let node: SKSpriteNode
    private let type: Int
    private let winged: Bool
    private var textures: [SKTexture] = []
    private var time: CGFloat = 0

    init(node: SKSpriteNode, type: Int, winged: Bool = false) {
        self.node = node
        self.type = type
        self.winged = winged
        let row = type == 4 ? 6 : type
        for column in 0..<2 {
            if let texture = SpriteSheet.texture(
                named: "enemysheet",
                cellSize: CGSize(width: 16, height: 16),
                column: column,
                row: row
            ) {
                textures.append(texture)
            }
        }
    }

    func update(dt: CGFloat, direction: CGFloat, onGround: Bool) {
        guard textures.count >= 2 else { return }
        node.xScale = direction < 0 ? -1 : 1
        time += dt
        let frame = winged ? Int(time / (4.0 / 24.0)) % 2 : (onGround ? Int(time / (20.0 / 24.0)) % 2 : 1)
        node.texture = textures[frame]
    }
}
