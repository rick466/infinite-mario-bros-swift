import SpriteKit
import UIKit

final class GameScene: SKScene {
    private let virtualWidth: CGFloat = 320
    private let virtualHeight: CGFloat = 240
    private let tile: CGFloat = 16

    private var mario = SKSpriteNode()
    private var level = GameLevel()
    private let worldNode = SKNode()
    private var cameraNode = SKCameraNode()

    private var leftHeld = false
    private var rightHeld = false
    private var jumpHeld = false
    private var wasJumpHeld = false

    private var enemies: [SKSpriteNode] = []
    private var enemyDirections: [CGFloat] = []

    private var coins: [SKSpriteNode] = []
    private var collectedCoins = 0
    private var questionNodes: [String: SKSpriteNode] = [:]
    private var usedBlocks = Set<String>()

    private var coinLabel = SKLabelNode()
    private var velocity = CGVector.zero
    private var onGround = false
    private var lastTime: TimeInterval = 0

    private let runSpeed: CGFloat = 105
    private let jumpSpeed: CGFloat = 335
    private let gravity: CGFloat = -900
    private let maxFallSpeed: CGFloat = -430

    override func didMove(to view: SKView) {
        scaleMode = .aspectFit
        backgroundColor = .black
        size = CGSize(width: virtualWidth, height: virtualHeight)

        addChild(worldNode)
        buildWorld()
        setupCamera()
        spawnEnemies()
        spawnCoins()
        addHUD()
        addTouchControls()
    }

    private func buildWorld() {
        let sky = SKSpriteNode(
            color: SKColor(red: 0.40, green: 0.65, blue: 0.95, alpha: 1),
            size: CGSize(width: CGFloat(level.width) * tile, height: virtualHeight)
        )
        sky.position = CGPoint(x: CGFloat(level.width) * tile / 2, y: virtualHeight / 2)
        sky.zPosition = -20
        worldNode.addChild(sky)

        let levelNode = SKNode()
        levelNode.name = "level"

        for x in 0..<level.width {
            for y in 0..<level.height where level.tiles[x][y] {
                if level.questionBlockPositions.contains(where: { $0.x == x && $0.y == y }) {
                    continue
                }

                let node = SKSpriteNode(
                    color: y >= 10
                        ? SKColor(red: 0.47, green: 0.29, blue: 0.12, alpha: 1)
                        : SKColor(red: 0.82, green: 0.55, blue: 0.18, alpha: 1),
                    size: CGSize(width: tile, height: tile)
                )
                node.position = CGPoint(
                    x: CGFloat(x) * tile + tile / 2,
                    y: worldY(row: y) + tile / 2
                )
                levelNode.addChild(node)
            }
        }
        worldNode.addChild(levelNode)

        for p in level.questionBlockPositions {
            let node = makeQuestionBlock(used: false)
            node.position = tileCenter(x: p.x, row: p.y)
            worldNode.addChild(node)
            questionNodes[key(p.x, p.y)] = node
        }

        if let texture = SpriteSheet.texture(
            named: "mariosheet",
            cellSize: CGSize(width: 32, height: 32),
            column: 0,
            row: 0
        ) {
            mario = SKSpriteNode(texture: texture)
        } else {
            mario = SKSpriteNode(color: .red, size: CGSize(width: 24, height: 32))
        }

        mario.size = CGSize(width: 32, height: 32)
        mario.position = CGPoint(x: 48, y: worldY(row: 10) + 16)
        mario.zPosition = 10
        worldNode.addChild(mario)
    }

    private func makeQuestionBlock(used: Bool) -> SKSpriteNode {
        let node = SKSpriteNode(
            color: used
                ? SKColor(white: 0.45, alpha: 1)
                : SKColor(red: 0.95, green: 0.60, blue: 0.12, alpha: 1),
            size: CGSize(width: tile - 1, height: tile - 1)
        )

        if !used {
            let label = SKLabelNode(text: "?")
            label.fontName = "Menlo-Bold"
            label.fontSize = 11
            label.verticalAlignmentMode = .center
            label.fontColor = .white
            node.addChild(label)
        }

        return node
    }

    private func spawnCoins() {
        for p in level.coinPositions {
            let coin = SKShapeNode(circleOfRadius: 5)
            coin.fillColor = .yellow
            coin.strokeColor = .white
            coin.lineWidth = 1
            coin.position = tileCenter(x: p.x, row: p.y)
            coin.zPosition = 6
            worldNode.addChild(coin)
            coins.append(coin)

            let spin = SKAction.sequence([
                .scaleX(to: 0.25, duration: 0.35),
                .scaleX(to: 1.0, duration: 0.35)
            ])
            coin.run(.repeatForever(spin))
        }
    }

    private func addHUD() {
        coinLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        coinLabel.fontSize = 12
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.verticalAlignmentMode = .top
        coinLabel.position = CGPoint(x: -145, y: 108)
        coinLabel.zPosition = 200
        cameraNode.addChild(coinLabel)
        updateHUD()
    }

    private func updateHUD() {
        coinLabel.text = "COINS  \(collectedCoins)"
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: virtualWidth / 2, y: virtualHeight / 2)
        addChild(cameraNode)
        camera = cameraNode
    }

    private func spawnEnemies() {
        for p in level.enemyPositions {
            let enemy: SKSpriteNode
            if let texture = SpriteSheet.texture(
                named: "enemysheet",
                cellSize: CGSize(width: 16, height: 16),
                column: 0,
                row: 2
            ) {
                enemy = SKSpriteNode(texture: texture)
            } else {
                enemy = SKSpriteNode(color: .brown, size: CGSize(width: 22, height: 18))
            }

            enemy.size = CGSize(width: 24, height: 24)
            enemy.position = tileCenter(x: p.x, row: p.y)
            enemy.zPosition = 8
            worldNode.addChild(enemy)
            enemies.append(enemy)
            enemyDirections.append(-1)
        }
    }

    private func updateEnemies(_ dt: CGFloat) {
        var i = 0

        while i < enemies.count {
            let enemy = enemies[i]
            let direction = enemyDirections[i]
            let speed: CGFloat = 28

            enemy.position.x += direction * speed * dt

            let tileX = Int(floor(enemy.position.x / tile))
            let footRow = Int(floor((virtualHeight - enemy.position.y + 8) / tile))
            let aheadX = tileX + (direction > 0 ? 1 : -1)

            if !level.isSolid(aheadX, footRow) {
                enemyDirections[i] *= -1
                i += 1
                continue
            }

            if abs(enemy.position.x - mario.position.x) < 20 &&
               abs(enemy.position.y - mario.position.y) < 24 {
                if velocity.dy < -20 && mario.position.y > enemy.position.y {
                    enemy.removeFromParent()
                    enemies.remove(at: i)
                    enemyDirections.remove(at: i)
                    velocity.dy = jumpSpeed * 0.55
                    continue
                }

                resetMario()
                return
            }

            i += 1
        }
    }

    private func addTouchControls() {
        let controls = [
            ("LEFT", CGPoint(x: 42, y: 38), 0),
            ("RIGHT", CGPoint(x: 98, y: 38), 1),
            ("JUMP", CGPoint(x: virtualWidth - 58, y: 38), 2)
        ]

        for (title, position, type) in controls {
            let node = SKShapeNode(circleOfRadius: 24)
            node.fillColor = SKColor(white: 1, alpha: 0.25)
            node.strokeColor = .white
            node.lineWidth = 2
            node.position = position
            node.name = "control_\(type)"
            node.zPosition = 100

            let label = SKLabelNode(text: title)
            label.fontName = "Menlo-Bold"
            label.fontSize = 8
            label.verticalAlignmentMode = .center
            label.name = node.name
            node.addChild(label)

            cameraNode.addChild(node)
        }
    }

    private func worldY(row: Int) -> CGFloat {
        virtualHeight - CGFloat(row + 1) * tile
    }

    private func tileCenter(x: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(x) * tile + tile / 2,
            y: worldY(row: row) + tile / 2
        )
    }

    private func key(_ x: Int, _ y: Int) -> String {
        "\(x):\(y)"
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { handleTouch(touch, pressed: true) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { handleTouch(touch, pressed: true) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { handleTouch(touch, pressed: false) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { handleTouch(touch, pressed: false) }
    }

    private func handleTouch(_ touch: UITouch, pressed: Bool) {
        let p = touch.location(in: cameraNode)

        if p.x < 72 && p.y < 72 {
            leftHeld = pressed
        } else if p.x < 128 && p.y < 72 {
            rightHeld = pressed
        } else if p.x > virtualWidth - 120 && p.y < 72 {
            jumpHeld = pressed
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = min(
            CGFloat(1.0 / 60.0),
            CGFloat(currentTime - (lastTime == 0 ? currentTime : lastTime))
        )
        lastTime = currentTime

        let direction = (rightHeld ? 1 : 0) - (leftHeld ? 1 : 0)
        velocity.dx = CGFloat(direction) * runSpeed

        if jumpHeld && !wasJumpHeld && onGround {
            velocity.dy = jumpSpeed
            onGround = false
        }
        wasJumpHeld = jumpHeld

        velocity.dy = max(velocity.dy + gravity * dt, maxFallSpeed)

        moveX(velocity.dx * dt)
        moveY(velocity.dy * dt)
        collectCoins()
        updateEnemies(dt)
        updateCamera()
    }

    private func collectCoins() {
        for coin in coins where coin.parent != nil {
            if abs(coin.position.x - mario.position.x) < 14 &&
               abs(coin.position.y - mario.position.y) < 20 {
                coin.removeFromParent()
                collectedCoins += 1
                updateHUD()
            }
        }
    }

    private func moveX(_ amount: CGFloat) {
        let halfW: CGFloat = 11
        let newX = mario.position.x + amount

        if amount > 0 && collides(
            left: newX + halfW, right: newX + halfW,
            top: mario.position.y + 14, bottom: mario.position.y - 14
        ) {
            mario.position.x = floor((newX + halfW) / tile) * tile - halfW - 0.1
            velocity.dx = 0
        } else if amount < 0 && collides(
            left: newX - halfW, right: newX - halfW,
            top: mario.position.y + 14, bottom: mario.position.y - 14
        ) {
            mario.position.x = floor((newX - halfW) / tile + 1) * tile + halfW + 0.1
            velocity.dx = 0
        } else {
            mario.position.x = newX
        }
    }

    private func moveY(_ amount: CGFloat) {
        let halfW: CGFloat = 11
        let halfH: CGFloat = 14
        let newY = mario.position.y + amount

        if amount <= 0 {
            let bottom = newY - halfH

            if collides(
                left: mario.position.x - halfW,
                right: mario.position.x + halfW,
                top: newY + halfH,
                bottom: bottom
            ) {
                let row = Int(floor((virtualHeight - bottom) / tile))
                mario.position.y = worldY(row: row) + halfH
                velocity.dy = 0
                onGround = true
                return
            }

            onGround = false
        } else {
            let top = newY + halfH

            if collides(
                left: mario.position.x - halfW,
                right: mario.position.x + halfW,
                top: top,
                bottom: newY - halfH
            ) {
                hitBlock(fromBelow: top)
                mario.position.y = CGFloat(floor(top / tile)) * tile - halfH - 0.1
                velocity.dy = 0
                return
            }
        }

        mario.position.y = newY

        if mario.position.y < -40 {
            resetMario()
        }
    }

    private func hitBlock(fromBelow top: CGFloat) {
        let row = Int(floor((virtualHeight - top) / tile))
        let centerX = Int(floor(mario.position.x / tile))

        for x in (centerX - 1)...(centerX + 1) {
            let k = key(x, row)

            if level.questionBlockPositions.contains(where: { $0.x == x && $0.y == row }) &&
               !usedBlocks.contains(k) {
                usedBlocks.insert(k)

                if let old = questionNodes[k] {
                    let position = old.position
                    old.removeFromParent()

                    let used = makeQuestionBlock(used: true)
                    used.position = position
                    worldNode.addChild(used)
                    questionNodes[k] = used
                }

                spawnBonusCoin(at: tileCenter(x: x, row: row - 1))
                break
            }
        }
    }

    private func spawnBonusCoin(at position: CGPoint) {
        let coin = SKShapeNode(circleOfRadius: 5)
        coin.fillColor = .yellow
        coin.strokeColor = .white
        coin.lineWidth = 1
        coin.position = position
        coin.zPosition = 12
        worldNode.addChild(coin)

        let rise = SKAction.moveBy(x: 0, y: 18, duration: 0.16)
        let fade = SKAction.fadeOut(withDuration: 0.16)
        coin.run(.group([rise, fade])) {
            coin.removeFromParent()
        }

        collectedCoins += 1
        updateHUD()
    }

    private func collides(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat) -> Bool {
        let minX = Int(floor(left / tile))
        let maxX = Int(floor(right / tile))
        let minY = Int(floor((virtualHeight - top) / tile))
        let maxY = Int(floor((virtualHeight - bottom) / tile))

        for x in minX...maxX {
            for y in minY...maxY {
                if level.isSolid(x, y) {
                    return true
                }
            }
        }
        return false
    }

    private func resetMario() {
        mario.position = CGPoint(x: 48, y: worldY(row: 10) + 16)
        velocity = .zero
        onGround = false
        cameraNode.position.x = virtualWidth / 2
    }

    private func updateCamera() {
        let targetX = max(virtualWidth / 2, mario.position.x)
        let maxX = CGFloat(level.width) * tile - virtualWidth / 2
        let cameraX = min(max(targetX, virtualWidth / 2), maxX)

        cameraNode.position.x += (cameraX - cameraNode.position.x) * 0.12
        cameraNode.position.y = virtualHeight / 2
    }
}
