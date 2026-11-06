import SpriteKit
import UIKit

final class GameScene: SKScene {
    private let virtualWidth: CGFloat = 320
    private let virtualHeight: CGFloat = 240
    private let tile: CGFloat = 16

    private enum ScreenState { case title, map, playing, clear, gameOver }
    private var screenState: ScreenState = .title
    private var stage = 0
    private let stageCount = 3

    private var mario = SKSpriteNode()
    private var marioAnimator: MarioAnimator?
    private var isBigMario = true
    private var isFireMario = false
    private var damageInvulnerability: CGFloat = 0

    private var leftHeld = false
    private var rightHeld = false
    private var jumpHeld = false
    private var downHeld = false
    private var firePressed = false
    private var wasJumpHeld = false
    private var wasFirePressed = false

    private var velocity = CGVector.zero
    private var onGround = false
    private var jumpTime: CGFloat = 0
    private var lastTime: TimeInterval = 0

    private var level = GameLevel(stage: 0)
    private let worldNode = SKNode()
    private var cameraNode = SKCameraNode()

    private var enemies: [SKSpriteNode] = []
    private var enemyKinds: [Int] = []
    private var enemyDirections: [CGFloat] = []
    private var enemyAnimators: [EnemyAnimator?] = []

    private var coins: [SKShapeNode] = []
    private var powerUps: [SKShapeNode] = []
    private var powerUpKinds: [ObjectIdentifier: String] = [:]
    private var powerUpVelocity: [ObjectIdentifier: CGVector] = [:]
    private var powerUpDirections: [ObjectIdentifier: CGFloat] = [:]

    private var fireballs: [SKShapeNode] = []
    private var fireballVelocity: [ObjectIdentifier: CGVector] = [:]

    private var questionNodes: [String: SKSpriteNode] = [:]
    private var usedBlocks = Set<String>()
    private var flagNode = SKShapeNode()

    private var collectedCoins = 0
    private var score = 0
    private var lives = 3
    private var timeLeft: CGFloat = 300
    private var goalX: CGFloat = 0

    private var hudLabel = SKLabelNode()
    private var stateLabel = SKLabelNode()
    private var titleLabel = SKLabelNode()
    private var mapNodes: [SKShapeNode] = []
    private var mapStageLabels: [SKLabelNode] = []
    private var selectedMapStage = 0
    private var shouldResetLives = false

    private let sound = SoundManager()

    private let runSpeed: CGFloat = 105
    private let jumpSpeed: CGFloat = 315
    private let gravity: CGFloat = -1050
    private let maxFallSpeed: CGFloat = -520

    override func didMove(to view: SKView) {
        scaleMode = .aspectFit
        backgroundColor = .black
        size = CGSize(width: virtualWidth, height: virtualHeight)
        showTitle()
    }

    private func clearScene() {
        removeAllActions()
        removeAllChildren()
        worldNode.removeAllChildren()
        enemies.removeAll()
        enemyKinds.removeAll()
        enemyDirections.removeAll()
        enemyAnimators.removeAll()
        coins.removeAll()
        powerUps.removeAll()
        fireballs.removeAll()
        questionNodes.removeAll()
        usedBlocks.removeAll()
        powerUpKinds.removeAll()
        powerUpVelocity.removeAll()
        powerUpDirections.removeAll()
        fireballVelocity.removeAll()
        cameraNode = SKCameraNode()
        mario = SKSpriteNode()
        marioAnimator = nil
        flagNode = SKShapeNode()
        velocity = .zero
        lastTime = 0
        leftHeld = false
        rightHeld = false
        jumpHeld = false
        downHeld = false
        firePressed = false
        wasJumpHeld = false
        wasFirePressed = false
    }

    private func showTitle() {
        clearScene()
        shouldResetLives = true
        screenState = .title

        let sky = SKShapeNode(rectOf: CGSize(width: virtualWidth, height: virtualHeight))
        sky.fillColor = SKColor(red: 0.08, green: 0.22, blue: 0.48, alpha: 1)
        sky.strokeColor = .clear
        sky.position = CGPoint(x: virtualWidth / 2, y: virtualHeight / 2)
        addChild(sky)

        let logo = SKLabelNode(fontNamed: "Menlo-Bold")
        logo.text = "MARIO"
        logo.fontSize = 42
        logo.fontColor = .white
        logo.position = CGPoint(x: virtualWidth / 2, y: 145)
        addChild(logo)
        titleLabel = logo

        let sub = SKLabelNode(fontNamed: "Menlo-Bold")
        sub.text = "INFINITE SWIFT"
        sub.fontSize = 13
        sub.fontColor = .yellow
        sub.position = CGPoint(x: virtualWidth / 2, y: 120)
        addChild(sub)

        let marioTitle = SKSpriteNode()
        if let texture = SpriteSheet.texture(named: "mariosheet", cellSize: CGSize(width: 32, height: 32), column: 0, row: 0) {
            marioTitle.texture = texture
        } else {
            marioTitle.color = .red
            marioTitle.size = CGSize(width: 32, height: 32)
        }
        marioTitle.size = CGSize(width: 48, height: 48)
        marioTitle.position = CGPoint(x: virtualWidth / 2, y: 78)
        addChild(marioTitle)

        let start = SKLabelNode(fontNamed: "Menlo-Bold")
        start.text = "TOUCH TO START"
        start.fontSize = 14
        start.fontColor = .white
        start.position = CGPoint(x: virtualWidth / 2, y: 38)
        start.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.6),
            .fadeAlpha(to: 1, duration: 0.6)
        ])))
        addChild(start)
    }

    private func showWorldMap() {
        clearScene()
        screenState = .map
        selectedMapStage = min(stage, stageCount - 1)

        let bg = SKShapeNode(rectOf: CGSize(width: virtualWidth, height: virtualHeight))
        bg.fillColor = SKColor(red: 0.20, green: 0.48, blue: 0.28, alpha: 1)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: virtualWidth / 2, y: virtualHeight / 2)
        addChild(bg)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "WORLD 1"
        title.fontSize = 24
        title.fontColor = .white
        title.position = CGPoint(x: virtualWidth / 2, y: 190)
        addChild(title)

        let path = SKShapeNode()
        let points = [CGPoint(x: 50, y: 90), CGPoint(x: 145, y: 130), CGPoint(x: 240, y: 85)]
        for (i, p) in points.enumerated() {
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.strokeColor = .white
        path.lineWidth = 5
        addChild(path)

        for i in 0..<stageCount {
            let node = SKShapeNode(circleOfRadius: 17)
            node.position = points[i]
            node.fillColor = i <= stage ? .yellow : .gray
            node.strokeColor = .white
            node.lineWidth = 2
            node.name = "map_stage_\(i)"
            addChild(node)
            mapNodes.append(node)

            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = "\(i + 1)"
            label.fontSize = 14
            label.verticalAlignmentMode = .center
            label.fontColor = .black
            label.position = CGPoint(x: points[i].x, y: points[i].y - 6)
            label.name = node.name
            addChild(label)
            mapStageLabels.append(label)
        }

        let hint = SKLabelNode(fontNamed: "Menlo-Bold")
        hint.text = "TAP A STAGE"
        hint.fontSize = 11
        hint.fontColor = .white
        hint.position = CGPoint(x: virtualWidth / 2, y: 35)
        addChild(hint)
    }

    private func startStage(_ index: Int) {
        stage = max(0, min(index, stageCount - 1))
        if shouldResetLives { lives = 3; shouldResetLives = false }
        level = GameLevel(stage: stage)
        collectedCoins = 0
        score = 0
        timeLeft = 300
        isBigMario = true
        isFireMario = false
        screenState = .playing
        clearScene()
        screenState = .playing
        buildWorld()
        marioAnimator = MarioAnimator(node: mario)
        setupCamera()
        spawnEnemies()
        spawnCoins()
        addHUD()
        addTouchControls()
        showStateMessage("WORLD 1-\(stage + 1)", duration: 1.2)
    }

    private func buildWorld() {
        worldNode.position = .zero
        addChild(worldNode)

        let sky = SKSpriteNode(
            color: stage == 1 ? SKColor(red: 0.12, green: 0.12, blue: 0.25, alpha: 1) :
                (stage == 2 ? SKColor(red: 0.25, green: 0.18, blue: 0.12, alpha: 1) :
                    SKColor(red: 0.40, green: 0.65, blue: 0.95, alpha: 1)),
            size: CGSize(width: CGFloat(level.width) * tile, height: virtualHeight)
        )
        sky.position = CGPoint(x: CGFloat(level.width) * tile / 2, y: virtualHeight / 2)
        sky.zPosition = -20
        worldNode.addChild(sky)

        let levelNode = SKNode()
        for x in 0..<level.width {
            for y in 0..<level.height where level.tiles[x][y] {
                if level.questionBlockPositions.contains(where: { $0.x == x && $0.y == y }) { continue }
                let tileID = Int(level.tileIDs[x][y])
                let column = tileID % 16
                let row = tileID / 16
                let node: SKSpriteNode
                if let texture = SpriteSheet.texture(named: "mapsheet", cellSize: CGSize(width: 16, height: 16), column: column, row: row) {
                    node = SKSpriteNode(texture: texture)
                } else {
                    node = SKSpriteNode(color: .brown, size: CGSize(width: tile, height: tile))
                }
                node.size = CGSize(width: tile, height: tile)
                node.position = tileCenter(x: x, row: y)
                levelNode.addChild(node)
            }
        }
        worldNode.addChild(levelNode)
        addPipeDecorations()
        addGoal()

        for p in level.questionBlockPositions {
            let node = makeQuestionBlock(used: false)
            node.position = tileCenter(x: p.x, row: p.y)
            worldNode.addChild(node)
            questionNodes[key(p.x, p.y)] = node
        }

        if let texture = SpriteSheet.texture(named: "mariosheet", cellSize: CGSize(width: 32, height: 32), column: 0, row: 0) {
            mario = SKSpriteNode(texture: texture)
        } else {
            mario = SKSpriteNode(color: .red, size: CGSize(width: 24, height: 32))
        }
        mario.size = CGSize(width: 32, height: 32)
        mario.position = CGPoint(x: 48, y: worldY(row: 10) + 16)
        mario.zPosition = 10
        worldNode.addChild(mario)
    }

    private func addPipeDecorations() {
        for x in 0..<(level.width - 1) {
            var y = 0
            while y < level.height - 2 {
                if level.isSolid(x, y) && level.isSolid(x + 1, y) &&
                    !level.isSolid(x, y - 1) && !level.isSolid(x + 1, y - 1) {
                    var end = y
                    while end + 1 < level.height && level.isSolid(x, end + 1) && level.isSolid(x + 1, end + 1) {
                        end += 1
                    }
                    if end - y >= 2 {
                        let bodyHeight = CGFloat(end - y + 1) * tile
                        let body = SKShapeNode(rectOf: CGSize(width: tile * 1.45, height: bodyHeight))
                        body.fillColor = .green
                        body.strokeColor = .darkGray
                        body.position = CGPoint(x: CGFloat(x) * tile + tile, y: worldY(row: end) + bodyHeight / 2)
                        body.zPosition = 3
                        body.name = "pipe"
                        worldNode.addChild(body)

                        let rim = SKShapeNode(rectOf: CGSize(width: tile * 2, height: 6))
                        rim.fillColor = .green
                        rim.strokeColor = .darkGray
                        rim.position = CGPoint(x: body.position.x, y: worldY(row: y) + tile + 1)
                        rim.zPosition = 4
                        rim.name = "pipe_rim"
                        worldNode.addChild(rim)
                    }
                    y = end + 1
                } else {
                    y += 1
                }
            }
        }
    }

    private func addGoal() {
        goalX = CGFloat(level.exitX) * tile
        let pole = SKShapeNode(rectOf: CGSize(width: 2, height: 112))
        pole.fillColor = .white
        pole.strokeColor = .white
        pole.position = CGPoint(x: goalX, y: 76)
        worldNode.addChild(pole)

        let flag = SKShapeNode(rectOf: CGSize(width: 26, height: 16))
        flag.fillColor = .red
        flag.strokeColor = .white
        flag.position = CGPoint(x: goalX + 13, y: 119)
        worldNode.addChild(flag)
        flagNode = flag

        let base = SKShapeNode(circleOfRadius: 6)
        base.fillColor = .white
        base.strokeColor = .white
        base.position = CGPoint(x: goalX, y: 20)
        worldNode.addChild(base)
    }

    private func makeQuestionBlock(used: Bool) -> SKSpriteNode {
        let node = SKSpriteNode(
            color: used ? SKColor(white: 0.45, alpha: 1) : SKColor(red: 0.95, green: 0.60, blue: 0.12, alpha: 1),
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

    private func addHUD() {
        setupCamera()
        hudLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        hudLabel.fontSize = 10
        hudLabel.horizontalAlignmentMode = .left
        hudLabel.verticalAlignmentMode = .top
        hudLabel.position = CGPoint(x: -153, y: 113)
        hudLabel.zPosition = 300
        cameraNode.addChild(hudLabel)
        updateHUD()
    }

    private func updateHUD() {
        let fire = isFireMario ? " FIRE" : ""
        hudLabel.text = "MARIO \(lives)   COIN \(String(format: "%02d", collectedCoins))   SCORE \(score)   WORLD 1-\(stage + 1)   TIME \(max(0, Int(timeLeft)))\(fire)"
    }

    private func setupCamera() {
        cameraNode.removeFromParent()
        addChild(cameraNode)
        cameraNode.position = CGPoint(x: virtualWidth / 2, y: virtualHeight / 2)
        camera = cameraNode
    }

    private func addTouchControls() {
        let controls = [
            ("◀", CGPoint(x: 38, y: 35), 0),
            ("▶", CGPoint(x: 88, y: 35), 1),
            ("▼", CGPoint(x: 138, y: 35), 4),
            ("JUMP", CGPoint(x: virtualWidth - 82, y: 35), 2),
            ("FIRE", CGPoint(x: virtualWidth - 25, y: 78), 3)
        ]
        for (title, position, type) in controls {
            let node = SKShapeNode(circleOfRadius: 22)
            node.fillColor = SKColor(white: 1, alpha: 0.22)
            node.strokeColor = .white
            node.lineWidth = 2
            node.position = position
            node.name = "control_\(type)"
            node.zPosition = 400

            let label = SKLabelNode(text: title)
            label.fontName = "Menlo-Bold"
            label.fontSize = type == 2 || type == 3 ? 7 : 14
            label.verticalAlignmentMode = .center
            label.name = node.name
            node.addChild(label)
            cameraNode.addChild(node)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if screenState == .title {
            showWorldMap()
            return
        }
        if screenState == .map {
            for touch in touches {
                let p = touch.location(in: self)
                if let index = mapNodes.firstIndex(where: { $0.contains(p) }), index <= stage {
                    startStage(index)
                    return
                }
            }
            return
        }
        if screenState == .clear {
            if stage + 1 < stageCount {
                showWorldMap()
            } else {
                stage = 0
                showTitle()
            }
            return
        }
        if screenState == .gameOver {
            showWorldMap()
            return
        }
        for touch in touches { handleTouch(touch, pressed: true) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard screenState == .playing else { return }
        for touch in touches { handleTouch(touch, pressed: true) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard screenState == .playing else { return }
        for touch in touches { handleTouch(touch, pressed: false) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard screenState == .playing else { return }
        for touch in touches { handleTouch(touch, pressed: false) }
    }

    private func handleTouch(_ touch: UITouch, pressed: Bool) {
        let p = touch.location(in: cameraNode)
        if p.x < 65 && p.y < 70 {
            leftHeld = pressed
        } else if p.x < 115 && p.y < 70 {
            rightHeld = pressed
        } else if p.x < 165 && p.y < 70 {
            downHeld = pressed
        } else if p.x > virtualWidth - 145 && p.y < 70 {
            jumpHeld = pressed
        } else if p.x > virtualWidth - 60 && p.y < 115 {
            firePressed = pressed
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard screenState == .playing else { return }
        let dt = min(CGFloat(1.0 / 30.0), CGFloat(currentTime - (lastTime == 0 ? currentTime : lastTime)))
        lastTime = currentTime

        timeLeft -= dt
        if timeLeft <= 0 {
            timeLeft = 0
            die()
            updateHUD()
            return
        }

        damageInvulnerability = max(0, damageInvulnerability - dt)
        let direction = (rightHeld ? 1 : 0) - (leftHeld ? 1 : 0)
        velocity.dx = CGFloat(direction) * runSpeed

        if jumpHeld && !wasJumpHeld && onGround {
            velocity.dy = jumpSpeed
            onGround = false
            jumpTime = 0
            sound.play(.jump)
        }
        if jumpHeld && !onGround && velocity.dy > 0 {
            jumpTime += dt
            if jumpTime < 0.16 { velocity.dy += 260 * dt }
        }
        if !jumpHeld && velocity.dy > 120 { velocity.dy *= 0.72 }
        wasJumpHeld = jumpHeld

        if firePressed && !wasFirePressed && isFireMario { spawnFireball() }
        wasFirePressed = firePressed

        if downHeld && onGround {
            tryEnterPipe()
        }

        velocity.dy = max(velocity.dy + gravity * dt, maxFallSpeed)
        moveX(velocity.dx * dt)
        moveY(velocity.dy * dt)

        collectCoins()
        updatePowerUps(dt)
        updateFireballs(dt)
        updateEnemies(dt)

        marioAnimator?.update(dt: dt, velocityY: velocity.dy, onGround: onGround)
        updateCamera()
        updateHUD()

        if mario.position.y < -30 { die() }
        checkGoal()
    }

    private func tryEnterPipe() {
        let tileX = Int(floor(mario.position.x / tile))
        for x in max(0, tileX - 1)...min(level.width - 2, tileX + 1) {
            let topRow = firstSolidRow(x: x)
            if topRow < level.height && level.isSolid(x, topRow) {
                let topY = worldY(row: topRow) + tile
                if abs(mario.position.y - topY) < 10 && abs(mario.position.x - (CGFloat(x) * tile + tile)) < 18 {
                    let target = min(level.width - 16, x + 14)
                    mario.position.x = CGFloat(target) * tile
                    velocity = .zero
                    return
                }
            }
        }
    }

    private func firstSolidRow(x: Int) -> Int {
        guard x >= 0 && x < level.width else { return level.height }
        for y in 0..<level.height where level.isSolid(x, y) { return y }
        return level.height
    }

    private func spawnEnemies() {
        for (index, p) in level.enemyPositions.enumerated() {
            let kind = level.enemyTypes[index]
            let winged = level.enemyWinged[index]
            let row = kind == 4 ? 6 : kind
            let texture = SpriteSheet.texture(
                named: "enemysheet",
                cellSize: CGSize(width: 16, height: 16),
                column: 0,
                row: row
            )
            let enemy = texture.map { SKSpriteNode(texture: $0) }
                ?? SKSpriteNode(color: kind == 3 ? .red : .brown, size: CGSize(width: 16, height: 16))
            enemy.size = kind == 4 ? CGSize(width: 32, height: 32) : CGSize(width: 16, height: 16)
            enemy.position = CGPoint(x: CGFloat(p.x) * tile + 8, y: worldY(row: p.y) + (kind == 4 ? 24 : 15))
            enemy.zPosition = 8
            if winged {
                let wings = SKShapeNode(ellipseOf: CGSize(width: 26, height: 8))
                wings.fillColor = .white
                wings.strokeColor = .clear
                wings.position = CGPoint(x: 0, y: 8)
                wings.name = "wings"
                enemy.addChild(wings)
            }
            worldNode.addChild(enemy)
            enemies.append(enemy)
            enemyKinds.append(kind)
            enemyDirections.append(index.isMultiple(of: 2) ? -1 : 1)
            enemyAnimators.append(kind == 2 || kind == 0 || kind == 1 || kind == 3
                ? EnemyAnimator(node: enemy, type: kind, winged: winged) : nil)
        }
    }

    private func updateEnemies(_ dt: CGFloat) {
        var i = 0
        while i < enemies.count {
            let enemy = enemies[i]
            let direction = enemyDirections[i]
            let speed: CGFloat = 1.75 * 24
            enemy.position.x += direction * speed * dt

            let tileX = Int(floor(enemy.position.x / tile))
            let footRow = Int(floor((virtualHeight - enemy.position.y + 8) / tile))
            let aheadX = tileX + (direction > 0 ? 1 : -1)
            if enemyKinds[i] == 0 && !level.isSolid(aheadX, footRow) {
                enemyDirections[i] *= -1
                i += 1
                continue
            }

            if damageInvulnerability <= 0 &&
                abs(enemy.position.x - mario.position.x) < 20 &&
                abs(enemy.position.y - mario.position.y) < 24 {
                if velocity.dy < -20 && mario.position.y > enemy.position.y && enemyKinds[i] != 3 && enemyKinds[i] != 4 {
                    if enemyKinds[i] == 0 || enemyKinds[i] == 1 {
                        enemyKinds[i] = 5
                        enemy.color = .white
                        enemy.size = CGSize(width: 22, height: 14)
                        score += 100
                        velocity.dy = jumpSpeed * 0.55
                        sound.play(.stomp)
                        i += 1
                        continue
                    }
                    enemy.removeFromParent()
                    enemies.remove(at: i)
                    enemyKinds.remove(at: i)
                    enemyDirections.remove(at: i)
                    enemyAnimators.remove(at: i)
                    score += 100
                    velocity.dy = jumpSpeed * 0.55
                    sound.play(.stomp)
                    continue
                }

                if isBigMario {
                    becomeSmallMario()
                    damageInvulnerability = 1.2
                    velocity.dy = 180
                    return
                } else {
                    die()
                    return
                }
            }

            enemyAnimators[i]?.update(dt: dt, direction: direction, onGround: true)
            i += 1
        }
    }

    private func spawnCoins() {
        for p in level.coinPositions {
            let coin = SKShapeNode(circleOfRadius: 5)
            coin.fillColor = .yellow
            coin.strokeColor = .white
            coin.position = tileCenter(x: p.x, row: p.y)
            coin.zPosition = 6
            worldNode.addChild(coin)
            coins.append(coin)
            coin.run(.repeatForever(.sequence([
                .scaleX(to: 0.25, duration: 0.28),
                .scaleX(to: 1, duration: 0.28)
            ])))
        }
    }

    private func collectCoins() {
        for coin in coins where coin.parent != nil {
            if abs(coin.position.x - mario.position.x) < 14 && abs(coin.position.y - mario.position.y) < 20 {
                coin.removeFromParent()
                collectedCoins += 1
                score += 100
                sound.play(.coin)
            }
        }
    }

    private func moveX(_ amount: CGFloat) {
        let halfW: CGFloat = isBigMario ? 11 : 7
        let newX = mario.position.x + amount
        if amount > 0 && collides(left: newX + halfW, right: newX + halfW, top: mario.position.y + 14, bottom: mario.position.y - 14) {
            mario.position.x = floor((newX + halfW) / tile) * tile - halfW - 0.1
            velocity.dx = 0
        } else if amount < 0 && collides(left: newX - halfW, right: newX - halfW, top: mario.position.y + 14, bottom: mario.position.y - 14) {
            mario.position.x = floor((newX - halfW) / tile + 1) * tile + halfW + 0.1
            velocity.dx = 0
        } else {
            mario.position.x = max(8, newX)
        }
    }

    private func moveY(_ amount: CGFloat) {
        let halfW: CGFloat = isBigMario ? 11 : 7
        let halfH: CGFloat = isBigMario ? 14 : 8
        let newY = mario.position.y + amount

        var resolvedY = newY
        if amount <= 0 {
            let bottom = newY - halfH
            if collides(left: mario.position.x - halfW, right: mario.position.x + halfW, top: newY, bottom: bottom) {
                let row = Int(floor((virtualHeight - bottom) / tile))
                resolvedY = worldY(row: row) + tile + halfH
                velocity.dy = 0
                onGround = true
            } else {
                onGround = false
            }
        } else {
            let top = newY + halfH
            if collides(left: mario.position.x - halfW, right: mario.position.x + halfW, top: top, bottom: newY) {
                let row = Int(floor((virtualHeight - top) / tile))
                resolvedY = worldY(row: row) - halfH - 0.1
                velocity.dy = 0
            }
            checkQuestionBlocks()
        }
        mario.position.y = resolvedY
    }

    private func checkQuestionBlocks() {
        guard velocity.dy > 0 else { return }
        let row = Int(floor((virtualHeight - (mario.position.y + 14)) / tile))
        let left = Int(floor((mario.position.x - 8) / tile))
        let right = Int(floor((mario.position.x + 8) / tile))
        for x in left...right {
            let k = key(x, row)
            if let block = questionNodes[k], !usedBlocks.contains(k) {
                usedBlocks.insert(k)
                block.texture = nil
                block.color = SKColor(white: 0.45, alpha: 1)
                block.removeAllChildren()
                spawnPowerUp(at: block.position)
                score += 200
                sound.play(.block)
            }
        }
    }

    private func spawnPowerUp(at position: CGPoint) {
        let power = SKShapeNode(circleOfRadius: 7)
        let kind = isBigMario ? "flower" : "mushroom"
        power.fillColor = kind == "flower" ? .yellow : .red
        power.strokeColor = .white
        power.position = CGPoint(x: position.x, y: position.y + 4)
        power.zPosition = 12
        worldNode.addChild(power)
        powerUps.append(power)
        let id = ObjectIdentifier(power)
        powerUpKinds[id] = kind
        powerUpVelocity[id] = CGVector(dx: 35, dy: 40)
        powerUpDirections[id] = 1
    }

    private func updatePowerUps(_ dt: CGFloat) {
        var i = 0
        while i < powerUps.count {
            let p = powerUps[i]
            let id = ObjectIdentifier(p)
            var v = powerUpVelocity[id] ?? CGVector(dx: 35, dy: 0)
            let d = powerUpDirections[id] ?? 1
            v.dy = max(v.dy + gravity * dt, maxFallSpeed)
            p.position.x += d * 35 * dt
            p.position.y += v.dy * dt

            if collides(left: p.position.x - 7, right: p.position.x + 7, top: p.position.y + 7, bottom: p.position.y - 7) {
                powerUpDirections[id] = -d
                v.dy = 0
            }

            if abs(p.position.x - mario.position.x) < 18 && abs(p.position.y - mario.position.y) < 24 {
                let kind = powerUpKinds[id] ?? "mushroom"
                p.removeFromParent()
                powerUps.remove(at: i)
                powerUpKinds.removeValue(forKey: id)
                powerUpVelocity.removeValue(forKey: id)
                powerUpDirections.removeValue(forKey: id)
                kind == "flower" ? becomeFireMario() : becomeBigMario()
                score += 1000
                continue
            }
            powerUpVelocity[id] = v
            i += 1
        }
    }

    private func spawnFireball() {
        let ball = SKShapeNode(circleOfRadius: 4)
        ball.fillColor = .orange
        ball.strokeColor = .white
        ball.position = CGPoint(x: mario.position.x + (mario.xScale < 0 ? -14 : 14), y: mario.position.y)
        worldNode.addChild(ball)
        fireballs.append(ball)
        fireballVelocity[ObjectIdentifier(ball)] = CGVector(dx: mario.xScale < 0 ? -180 : 180, dy: 60)
        sound.play(.fireball)
    }

    private func updateFireballs(_ dt: CGFloat) {
        var i = 0
        while i < fireballs.count {
            let b = fireballs[i]
            let id = ObjectIdentifier(b)
            var v = fireballVelocity[id] ?? .zero
            v.dy += gravity * 0.55 * dt
            b.position.x += v.dx * dt
            b.position.y += v.dy * dt

            if collides(left: b.position.x - 4, right: b.position.x + 4, top: b.position.y + 4, bottom: b.position.y - 4) {
                if v.dy < 0 { v.dy = 145 } else {
                    removeFireball(b, index: i)
                    continue
                }
            }

            var hit = false
            for enemy in enemies {
                if abs(enemy.position.x - b.position.x) < 14 && abs(enemy.position.y - b.position.y) < 16 {
                    enemy.removeFromParent()
                    if let index = enemies.firstIndex(of: enemy) {
                        enemies.remove(at: index)
                        enemyKinds.remove(at: index)
                        enemyDirections.remove(at: index)
                        enemyAnimators.remove(at: index)
                    }
                    score += 200
                    sound.play(.stomp)
                    hit = true
                    break
                }
            }
            if hit {
                removeFireball(b, index: i)
                continue
            }
            if b.position.x < 0 || b.position.x > CGFloat(level.width) * tile || b.position.y < -20 {
                removeFireball(b, index: i)
                continue
            }
            fireballVelocity[id] = v
            i += 1
        }
    }

    private func removeFireball(_ b: SKShapeNode, index: Int) {
        let id = ObjectIdentifier(b)
        b.removeFromParent()
        fireballs.remove(at: index)
        fireballVelocity.removeValue(forKey: id)
    }

    private func checkGoal() {
        guard mario.position.x >= goalX - 10 else { return }
        screenState = .clear
        leftHeld = false; rightHeld = false; jumpHeld = false; downHeld = false; firePressed = false
        velocity = .zero
        flagNode.run(.moveTo(y: 55, duration: 0.45))
        let clear = SKLabelNode(fontNamed: "Menlo-Bold")
        clear.text = stage + 1 < stageCount ? "COURSE CLEAR!" : "WORLD CLEAR!"
        clear.fontSize = 22
        clear.fontColor = .white
        clear.position = CGPoint(x: 0, y: 20)
        clear.zPosition = 500
        cameraNode.addChild(clear)

        let next = SKLabelNode(fontNamed: "Menlo-Bold")
        next.text = stage + 1 < stageCount ? "TOUCH FOR WORLD MAP" : "TOUCH FOR TITLE"
        next.fontSize = 11
        next.fontColor = .white
        next.position = CGPoint(x: 0, y: -5)
        next.zPosition = 500
        cameraNode.addChild(next)
    }

    private func die() {
        guard screenState == .playing else { return }
        lives -= 1
        if lives > 0 {
            screenState = .gameOver
            showStateMessage("MARIO \(lives) REMAIN", duration: 0)
            let sub = SKLabelNode(fontNamed: "Menlo-Bold")
            sub.text = "TOUCH FOR WORLD MAP"
            sub.fontSize = 11
            sub.fontColor = .white
            sub.position = CGPoint(x: 0, y: 5)
            sub.zPosition = 500
            cameraNode.addChild(sub)
        } else {
            screenState = .gameOver
            showStateMessage("GAME OVER", duration: 0)
            let sub = SKLabelNode(fontNamed: "Menlo-Bold")
            sub.text = "TOUCH FOR TITLE"
            sub.fontSize = 11
            sub.fontColor = .white
            sub.position = CGPoint(x: 0, y: 5)
            sub.zPosition = 500
            cameraNode.addChild(sub)
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
            stateLabel.run(.sequence([.wait(forDuration: duration), .fadeOut(withDuration: 0.25)]))
        }
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
        if let texture = SpriteSheet.texture(named: "firemariosheet", cellSize: CGSize(width: 32, height: 32), column: 0, row: 0) {
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
        if let texture = SpriteSheet.texture(named: "smallmariosheet", cellSize: CGSize(width: 16, height: 16), column: 0, row: 0) {
            mario.texture = texture
        }
    }

    private func collides(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat) -> Bool {
        let minX = Int(floor(left / tile))
        let maxX = Int(floor(right / tile))
        let minY = Int(floor((virtualHeight - top) / tile))
        let maxY = Int(floor((virtualHeight - bottom) / tile))
        for x in minX...maxX {
            for y in minY...maxY where level.isSolid(x, y) { return true }
        }
        return false
    }

    private func updateCamera() {
        let targetX = max(virtualWidth / 2, mario.position.x)
        let maxX = CGFloat(level.width) * tile - virtualWidth / 2
        let cameraX = min(max(targetX, virtualWidth / 2), maxX)
        cameraNode.position.x += (cameraX - cameraNode.position.x) * 0.12
        cameraNode.position.y = virtualHeight / 2
    }

    private func worldY(row: Int) -> CGFloat {
        virtualHeight - CGFloat(row + 1) * tile
    }

    private func tileCenter(x: Int, row: Int) -> CGPoint {
        CGPoint(x: CGFloat(x) * tile + tile / 2, y: worldY(row: row) + tile / 2)
    }

    private func key(_ x: Int, _ y: Int) -> String { "\(x):\(y)" }
}
