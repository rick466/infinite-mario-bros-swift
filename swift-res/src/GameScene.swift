import SpriteKit
import UIKit

final class GameScene: SKScene {
    private let virtualWidth: CGFloat = 320
    private let virtualHeight: CGFloat = 240
    private let tile: CGFloat = 16

    private var mario = SKSpriteNode()
    private var marioAnimator: MarioAnimator?
    private var isBigMario = true
    private var isFireMario = false
    private var damageInvulnerability: CGFloat = 0
    private var firePressed = false
    private var wasFirePressed = false
    private var fireballs: [SKShapeNode] = []
    private var fireballVelocity: [ObjectIdentifier: CGVector] = [:]
    private var winLabel = SKLabelNode()
    private var stateLabel = SKLabelNode()
    private var gameFinished = false
    private var gameOver = false
    private var goalX: CGFloat = 0
    private var flagNode = SKShapeNode()
    private var level = GameLevel()
    private let worldNode = SKNode()
    private var cameraNode = SKCameraNode()

    private var leftHeld = false
    private var rightHeld = false
    private var jumpHeld = false
    private var wasJumpHeld = false
    private var jumpTime: CGFloat = 0
    private var wasOnGround = false
    private let sound = SoundManager()

    private var enemies: [SKSpriteNode] = []
    private var enemyDirections: [CGFloat] = []
    private var enemyAnimators: [EnemyAnimator] = []

    private var coins: [SKSpriteNode] = []
    private var collectedCoins = 0
    private var questionNodes: [String: SKSpriteNode] = [:]
    private var usedBlocks = Set<String>()
    private var powerUps: [SKSpriteNode] = []
    private var mushroomVelocity: [ObjectIdentifier: CGFloat] = [:]
    private var mushroomDirections: [ObjectIdentifier: CGFloat] = [:]
    private var powerUpKinds: [ObjectIdentifier: String] = [:]

    private var coinLabel = SKLabelNode()
    private var velocity = CGVector.zero
    private var onGround = false
    private var lastTime: TimeInterval = 0

    private let runSpeed: CGFloat = 105
    private let jumpSpeed: CGFloat = 315
    private let gravity: CGFloat = -1050
    private let maxFallSpeed: CGFloat = -520

    override func didMove(to view: SKView) {
        scaleMode = .aspectFit
        backgroundColor = .black
        size = CGSize(width: virtualWidth, height: virtualHeight)

        addChild(worldNode)
        buildWorld()
        marioAnimator = MarioAnimator(node: mario)
        setupCamera()
        spawnEnemies()
        spawnCoins()
        addHUD()
        addTouchControls()
        showStateMessage("WORLD 1-1", duration: 1.4)
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
                    color: .brown,
                    size: CGSize(width: tile, height: tile)
                )
                node.position = CGPoint(
                    x: CGFloat(x) * tile + tile / 2,
                    y: worldY(row: y) + tile / 2
                )
                if let texture = SpriteSheet.texture(named: "mapsheet", cellSize: CGSize(width: 16, height: 16), column: 1, row: 9) {
                    node.texture = texture
                }
                levelNode.addChild(node)
            }
        }
        worldNode.addChild(levelNode)
        addGoal()

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
        mario.position = CGPoint(x: 48, y: worldY(row: 10) + (isBigMario ? 16 : 8))
        mario.zPosition = 10
        worldNode.addChild(mario)
    }

    private func addGoal() {
        goalX = CGFloat(level.width - 10) * tile
        let pole = SKShapeNode(rectOf: CGSize(width: 2, height: 112))
        pole.fillColor = .white
        pole.strokeColor = .white
        pole.position = CGPoint(x: goalX, y: 76)
        pole.zPosition = 4
        worldNode.addChild(pole)

        let flag = SKShapeNode(rectOf: CGSize(width: 26, height: 16))
        flag.fillColor = .red
        flag.strokeColor = .white
        flag.position = CGPoint(x: goalX + 13, y: 119)
        flag.zPosition = 5
        worldNode.addChild(flag)
        flagNode = flag

        let base = SKShapeNode(circleOfRadius: 6)
        base.fillColor = .white
        base.strokeColor = .white
        base.position = CGPoint(x: goalX, y: 20)
        base.zPosition = 4
        worldNode.addChild(base)
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
        coinLabel.text = isFireMario ? "COINS  \(collectedCoins)  FIRE" : "COINS  \(collectedCoins)"
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
            enemyAnimators.append(EnemyAnimator(node: enemy))
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

            if damageInvulnerability <= 0 && abs(enemy.position.x - mario.position.x) < 20 &&
               abs(enemy.position.y - mario.position.y) < 24 {
                if velocity.dy < -20 && mario.position.y > enemy.position.y {
                    enemy.removeFromParent()
                    enemies.remove(at: i)
                    enemyDirections.remove(at: i)
                    enemyAnimators.remove(at: i)
                    velocity.dy = jumpSpeed * 0.55
                    sound.play(.stomp)
                    continue
                }

                if isBigMario {
                    becomeSmallMario()
                    damageInvulnerability = 1.2
                    velocity.dy = 180
                } else {
                    die()
                }
                return
            }

            enemyAnimators[i].update(dt: dt, direction: direction, onGround: true)
            i += 1
        }
    }

    private func addTouchControls() {
        let controls = [
            ("LEFT", CGPoint(x: 42, y: 38), 0),
            ("RIGHT", CGPoint(x: 98, y: 38), 1),
            ("JUMP", CGPoint(x: virtualWidth - 88, y: 38), 2),
            ("FIRE", CGPoint(x: virtualWidth - 28, y: 78), 3)
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
        if gameOver || gameFinished {
            restartGame()
            return
        }
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
        } else if p.x > virtualWidth - 145 && p.y < 72 {
            jumpHeld = pressed
        } else if p.x > virtualWidth - 75 && p.y < 115 {
            firePressed = pressed
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = min(
            CGFloat(1.0 / 60.0),
            CGFloat(currentTime - (lastTime == 0 ? currentTime : lastTime))
        )
        lastTime = currentTime
        guard !gameFinished && !gameOver else { return }

        let direction = (rightHeld ? 1 : 0) - (leftHeld ? 1 : 0)
        velocity.dx = CGFloat(direction) * runSpeed

        wasOnGround = onGround

        if jumpHeld && !wasJumpHeld && onGround {
            velocity.dy = jumpSpeed
            onGround = false
            jumpTime = 0
            sound.play(.jump)
        }
        if jumpHeld && !onGround && velocity.dy > 0 {
            jumpTime += dt
            if jumpTime < 0.16 {
                velocity.dy += 260 * dt
            }
        }
        if !jumpHeld && velocity.dy > 120 {
            velocity.dy *= 0.72
        }
        wasJumpHeld = jumpHeld
        if firePressed && !wasFirePressed && isFireMario { spawnFireball() }
        wasFirePressed = firePressed

        velocity.dy = max(velocity.dy + gravity * dt, maxFallSpeed)

        moveX(velocity.dx * dt)
        moveY(velocity.dy * dt)
        collectCoins()
        updatePowerUps(dt)
        updateFireballs(dt)
        updateEnemies(dt)
        marioAnimator?.update(dt: dt, velocityY: velocity.dy, onGround: onGround)
        updateCamera()
        checkGoal()
    }

    private func checkGoal() {
        guard !gameFinished && !gameOver else { return }
        if mario.position.x >= goalX - 10 {
            gameFinished = true
            leftHeld = false
            rightHeld = false
            jumpHeld = false
            firePressed = false
            velocity = .zero

            let slide = SKAction.moveTo(y: 55, duration: 0.45)
            flagNode.run(slide)

            winLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            winLabel.text = "COURSE CLEAR!"
            winLabel.fontSize = 24
            winLabel.fontColor = .white
            winLabel.position = CGPoint(x: 0, y: 10)
            winLabel.zPosition = 500
            cameraNode.addChild(winLabel)

            showStateMessage("TOUCH TO PLAY AGAIN", duration: 0)
        }
    }

    private func showStateMessage(_ text: String, duration: TimeInterval) {
        stateLabel.removeFromParent()
        stateLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        stateLabel.text = text
        stateLabel.fontSize = 18
        stateLabel.fontColor = .white
        stateLabel.position = CGPoint(x: 0, y: 35)
        stateLabel.zPosition = 500
        cameraNode.addChild(stateLabel)

        if duration > 0 {
            stateLabel.run(.sequence([
                .wait(forDuration: duration),
                .fadeOut(withDuration: 0.25)
            ]))
        }
    }

    private func die() {
        guard !gameOver && !gameFinished else { return }
        gameOver = true
        leftHeld = false
        rightHeld = false
        jumpHeld = false
        firePressed = false
        velocity = .zero

        let jump = SKAction.sequence([
            .moveBy(x: 0, y: 32, duration: 0.25),
            .moveBy(x: 0, y: -80, duration: 0.55)
        ])
        mario.run(jump)

        showStateMessage("GAME OVER", duration: 0)
        let sub = SKLabelNode(fontNamed: "Menlo-Bold")
        sub.text = "TOUCH TO RETRY"
        sub.fontSize = 12
        sub.fontColor = .white
        sub.position = CGPoint(x: 0, y: 10)
        sub.zPosition = 500
        cameraNode.addChild(sub)
    }

    private func restartGame() {
        guard let view else { return }
        removeAllActions()
        removeAllChildren()
        mario = SKSpriteNode()
        cameraNode = SKCameraNode()
        enemies.removeAll()
        enemyDirections.removeAll()
        enemyAnimators.removeAll()
        coins.removeAll()
        powerUps.removeAll()
        fireballs.removeAll()
        mushroomVelocity.removeAll()
        mushroomDirections.removeAll()
        powerUpKinds.removeAll()
        fireballVelocity.removeAll()
        questionNodes.removeAll()
        usedBlocks.removeAll()
        collectedCoins = 0
        isBigMario = true
        isFireMario = false
        damageInvulnerability = 0
        gameFinished = false
        gameOver = false
        winLabel = SKLabelNode()
        stateLabel = SKLabelNode()
        lastTime = 0
        level = GameLevel()
        didMove(to: view)
    }

    private func collectCoins() {
        for coin in coins where coin.parent != nil {
            if abs(coin.position.x - mario.position.x) < 14 &&
               abs(coin.position.y - mario.position.y) < 20 {
                coin.removeFromParent()
                collectedCoins += 1
                sound.play(.coin)
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
            die()
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

                spawnMushroom(at: tileCenter(x: x, row: row - 1))
                sound.play(.powerUp)
                sound.play(.block)
                break
            }
        }
    }

    private func spawnMushroom(at position: CGPoint) {
        let power = SKShapeNode(circleOfRadius: 7)
        power.fillColor = isBigMario ? .yellow : .red
        power.strokeColor = .white
        power.lineWidth = 1
        power.position = CGPoint(x: position.x, y: position.y - 4)
        power.zPosition = 11
        power.name = "powerup"
        worldNode.addChild(power)
        powerUps.append(power)
        let id = ObjectIdentifier(power)
        mushroomVelocity[id] = 0
        mushroomDirections[id] = 1
        powerUpKinds[id] = isBigMario ? "flower" : "mushroom"

        let pop = SKAction.moveBy(x: 0, y: 16, duration: 0.18)
        power.run(pop)
    }

    private func updatePowerUps(_ dt: CGFloat) {
        var i = 0
        while i < powerUps.count {
            let power = powerUps[i]
            if power.parent == nil {
                powerUps.remove(at: i)
                continue
            }

            let id = ObjectIdentifier(power)
            var vy = mushroomVelocity[id] ?? 0
            let direction = mushroomDirections[id] ?? 1
            vy = max(vy + gravity * dt, maxFallSpeed)
            power.position.y += vy * dt
            power.position.x += direction * 38 * dt

            if collides(left: power.position.x - 7, right: power.position.x + 7,
                        top: power.position.y + 7, bottom: power.position.y - 7) {
                mushroomDirections[id] = -direction
            }

            if abs(power.position.x - mario.position.x) < 18 &&
               abs(power.position.y - mario.position.y) < 24 {
                let kind = powerUpKinds[id] ?? "mushroom"
                power.removeFromParent()
                powerUps.remove(at: i)
                mushroomVelocity.removeValue(forKey: id)
                mushroomDirections.removeValue(forKey: id)
                powerUpKinds.removeValue(forKey: id)

                if kind == "flower" {
                    becomeFireMario()
                } else {
                    becomeBigMario()
                }
                continue
            }

            mushroomVelocity[id] = vy
            i += 1
        }
    }

    private func spawnFireball() {
        let ball = SKShapeNode(circleOfRadius: 4)
        ball.fillColor = .orange
        ball.strokeColor = .white
        ball.lineWidth = 1
        ball.position = CGPoint(x: mario.position.x + (mario.xScale < 0 ? -14 : 14),
                                y: mario.position.y)
        ball.zPosition = 15
        worldNode.addChild(ball)
        fireballs.append(ball)

        let direction: CGFloat = mario.xScale < 0 ? -1 : 1
        fireballVelocity[ObjectIdentifier(ball)] = CGVector(dx: direction * 180, dy: 60)
        sound.play(.fireball)
    }

    private func updateFireballs(_ dt: CGFloat) {
        var i = 0
        while i < fireballs.count {
            let ball = fireballs[i]
            let id = ObjectIdentifier(ball)
            guard var v = fireballVelocity[id] else {
                ball.removeFromParent()
                fireballs.remove(at: i)
                continue
            }

            v.dy += gravity * 0.55 * dt
            ball.position.x += v.dx * dt
            ball.position.y += v.dy * dt

            if collides(left: ball.position.x - 4, right: ball.position.x + 4,
                        top: ball.position.y + 4, bottom: ball.position.y - 4) {
                if v.dy < 0 {
                    v.dy = 145
                    ball.position.y += 3
                } else {
                    removeFireball(ball, at: i)
                    continue
                }
            }

            var hitEnemy = false
            for e in enemies {
                if abs(e.position.x - ball.position.x) < 14 &&
                   abs(e.position.y - ball.position.y) < 16 {
                    e.removeFromParent()
                    if let index = enemies.firstIndex(of: e) {
                        enemies.remove(at: index)
                        enemyDirections.remove(at: index)
                        enemyAnimators.remove(at: index)
                    }
                    sound.play(.stomp)
                    hitEnemy = true
                    break
                }
            }

            if hitEnemy {
                removeFireball(ball, at: i)
                continue
            }

            if ball.position.x < 0 || ball.position.x > CGFloat(level.width) * tile ||
               ball.position.y < -20 {
                removeFireball(ball, at: i)
                continue
            }

            fireballVelocity[id] = v
            i += 1
        }
    }

    private func removeFireball(_ ball: SKShapeNode, at index: Int) {
        let id = ObjectIdentifier(ball)
        ball.removeFromParent()
        fireballVelocity.removeValue(forKey: id)
        fireballs.remove(at: index)
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
        sound.play(.coin)
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

    private func becomeBigMario() {
        isBigMario = true
        isFireMario = false
        mario.size = CGSize(width: 32, height: 32)
        marioAnimator = MarioAnimator(node: mario)
        sound.play(.powerUp)
    }

    private func becomeFireMario() {
        isBigMario = true
        isFireMario = true
        mario.size = CGSize(width: 32, height: 32)
        marioAnimator = MarioAnimator(node: mario)
        if let texture = SpriteSheet.texture(named: "firemariosheet",
                                              cellSize: CGSize(width: 32, height: 32),
                                              column: 0, row: 0) {
            mario.texture = texture
        }
        sound.play(.powerUp)
    }

    private func becomeSmallMario() {
        guard isBigMario else { return }
        isBigMario = false
        isFireMario = false
        mario.size = CGSize(width: 16, height: 16)
        marioAnimator = nil
        if let texture = SpriteSheet.texture(named: "smallmariosheet",
                                              cellSize: CGSize(width: 16, height: 16),
                                              column: 0, row: 0) {
            mario.texture = texture
        }
    }

    private func resetMario() {
        mario.position = CGPoint(x: 48, y: worldY(row: 10) + (isBigMario ? 16 : 8))
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
