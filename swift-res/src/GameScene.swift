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
    private var wasOnGround = false
    private var jumpTime: CGFloat = 0
    private var worldPauseTicks = 0
    private var facing: CGFloat = 1
    private var sliding = false
    private var lastTime: TimeInterval = 0
    private var tickAccumulator: CGFloat = 0

    private var level = GameLevel(stage: 0)
    private let worldNode = SKNode()
    private var cameraNode = SKCameraNode()

    private var enemies: [SKSpriteNode] = []
    private var enemyKinds: [Int] = []
    private var enemyDirections: [CGFloat] = []
    /// Enemy vertical velocity uses Java's screen-down-positive units per tick.
    private var enemyVerticalVelocities: [CGFloat] = []
    private var enemyGrounded: [Bool] = []
    private var enemyBaseY: [CGFloat] = []
    private var enemyHorizontalVelocities: [CGFloat] = []
    private var enemyTimers: [Int] = []
    private var enemyAnimators: [EnemyAnimator?] = []

    private var coins: [SKShapeNode] = []
    private var coinTilePositions: [ObjectIdentifier: SIMD2<Int>] = [:]
    private var powerUps: [SKSpriteNode] = []
    private var powerUpKinds: [ObjectIdentifier: String] = [:]
    private var powerUpVelocity: [ObjectIdentifier: CGVector] = [:]
    private var powerUpDirections: [ObjectIdentifier: CGFloat] = [:]
    private var powerUpTicks: [ObjectIdentifier: Int] = [:]
    private var tileNodes: [String: SKSpriteNode] = [:]

    private var fireballs: [SKShapeNode] = []
    private var fireballVelocity: [ObjectIdentifier: CGVector] = [:]

    private var questionNodes: [String: SKSpriteNode] = [:]
    private var usedBlocks = Set<String>()
    private var flagNode = SKShapeNode()

    private var collectedCoins = 0
    private var score = 0
    private var lives = 3
    private var timeLeft: CGFloat = 3000
    private var goalX: CGFloat = 0

    private var hudLabel = SKLabelNode()
    private var stateLabel = SKLabelNode()
    private var titleLabel = SKLabelNode()
    private var mapNodes: [SKShapeNode] = []
    private var mapStageLabels: [SKLabelNode] = []
    private var selectedMapStage = 0
    private var shouldResetLives = false

    private let sound = SoundManager()

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
        enemyVerticalVelocities.removeAll()
        enemyGrounded.removeAll()
        enemyBaseY.removeAll()
        enemyHorizontalVelocities.removeAll()
        enemyTimers.removeAll()
        enemyAnimators.removeAll()
        coins.removeAll()
        coinTilePositions.removeAll()
        powerUps.removeAll()
        fireballs.removeAll()
        questionNodes.removeAll()
        usedBlocks.removeAll()
        powerUpKinds.removeAll()
        powerUpVelocity.removeAll()
        powerUpDirections.removeAll()
        powerUpTicks.removeAll()
        tileNodes.removeAll()
        fireballVelocity.removeAll()
        cameraNode = SKCameraNode()
        mario = SKSpriteNode()
        marioAnimator = nil
        flagNode = SKShapeNode()
        velocity = .zero
        onGround = false
        wasOnGround = false
        sliding = false
        facing = 1
        jumpTime = 0
        worldPauseTicks = 0
        lastTime = 0
        tickAccumulator = 0
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
        if shouldResetLives {
            lives = 3
            collectedCoins = 0
            score = 0
            shouldResetLives = false
        }
        level = GameLevel(stage: stage)
        timeLeft = 3000
        isBigMario = false
        isFireMario = false
        screenState = .playing
        clearScene()
        screenState = .playing
        buildWorld()
        marioAnimator = MarioAnimator(node: mario, small: true)
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
            for y in 0..<level.height where level.tileIDs[x][y] != 0 {
                if level.isPickupable(x, y) { continue }
                let tileID = Int(level.tileIDs[x][y])
                let column = tileID % 16
                let row = tileID / 16
                let node = makeTileNode(tileID: tileID)
                node.position = tileCenter(x: x, row: y)
                levelNode.addChild(node)
                tileNodes[key(x, y)] = node
            }
        }
        worldNode.addChild(levelNode)
        addPipeDecorations()
        addGoal()

        for p in level.questionBlockPositions {
            if let node = tileNodes[key(p.x, p.y)] {
                questionNodes[key(p.x, p.y)] = node
            }
        }

        if let texture = SpriteSheet.texture(named: "smallmariosheet", cellSize: CGSize(width: 16, height: 16), column: 0, row: 0) {
            mario = SKSpriteNode(texture: texture)
        } else {
            mario = SKSpriteNode(color: .red, size: CGSize(width: 16, height: 16))
        }
        mario.size = CGSize(width: 16, height: 16)
        let spawnColumn = 3
        let spawnFloor = (0..<level.height).first(where: { level.isSolid(spawnColumn, $0) }) ?? (level.height - 1)
        mario.position = CGPoint(x: 48, y: worldY(row: spawnFloor) + tile + 8)
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
        hudLabel.text = "MARIO \(lives)   COIN \(String(format: "%02d", collectedCoins))   SCORE \(score)   WORLD 1-\(stage + 1)   TIME \(max(0, Int(timeLeft / 15)))\(fire)"
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

    /// The original Java game advances its simulation at 24 ticks per second.
    /// SpriteKit may render at 60/120 Hz, so gameplay is stepped at a fixed 24 Hz.
    override func update(_ currentTime: TimeInterval) {
        guard screenState == .playing else { return }
        let elapsed = lastTime == 0 ? 0 : max(0, currentTime - lastTime)
        lastTime = currentTime
        tickAccumulator += min(CGFloat(elapsed), 0.12)

        let fixedStep: CGFloat = 1.0 / 24.0
        while tickAccumulator >= fixedStep && screenState == .playing {
            simulateGameTick(dt: fixedStep)
            tickAccumulator -= fixedStep
        }
    }

    private func simulateGameTick(dt: CGFloat) {
        wasOnGround = onGround
        timeLeft -= 1
        if timeLeft <= 0 {
            timeLeft = 0
            die()
            updateHUD()
            return
        }
        if worldPauseTicks > 0 {
            worldPauseTicks -= 1
            marioAnimator?.update(dt: dt, velocityX: 0, velocityY: 0, onGround: onGround)
            updateHUD()
            return
        }

        damageInvulnerability = max(0, damageInvulnerability - dt)

        // Mario.java: KEY_SPEED changes horizontal acceleration from 0.6 to 1.2.
        // The FIRE touch control doubles as the original speed/action button.
        let direction = (rightHeld ? 1 : 0) - (leftHeld ? 1 : 0)
        let sideAcceleration: CGFloat = firePressed ? 1.2 : 0.6

        if velocity.dx > 2 { facing = 1 }
        if velocity.dx < -2 { facing = -1 }
        if direction < 0 {
            if facing == 1 { sliding = false }
            velocity.dx -= sideAcceleration
            if jumpTime >= 0 { facing = -1 }
        } else if direction > 0 {
            if facing == -1 { sliding = false }
            velocity.dx += sideAcceleration
            if jumpTime >= 0 { facing = 1 }
        }

        if jumpHeld && !wasJumpHeld {
            if sliding && !onGround {
                // Mario.java wall-slide jump: jumpTime=-6, xJumpSpeed=-facing*6.
                jumpTime = -6
                velocity.dx = -facing * 6
                velocity.dy = 12
                facing = -facing
                onGround = false
                sliding = false
                sound.play(.jump)
            } else if onGround {
                jumpTime = 7
                velocity.dy = 7 * 1.9
                onGround = false
                sliding = false
                sound.play(.jump)
            }
        } else if jumpHeld && jumpTime > 0 {
            velocity.dy = jumpTime * 1.9
            jumpTime -= 1
        } else if jumpHeld && jumpTime < 0 {
            velocity.dy = -jumpTime * 2
            velocity.dx = -facing * 6
            jumpTime += 1
        } else if !jumpHeld {
            jumpTime = 0
        }
        if direction == 0 || velocity.dy > 0 || onGround { sliding = false }
        mario.xScale = facing
        wasJumpHeld = jumpHeld

        if firePressed && !wasFirePressed && isFireMario {
            spawnFireball()
        }
        wasFirePressed = firePressed

        if downHeld && onGround {
            tryEnterPipe()
        }

        // Java's move() applies movement first, then 0.85 vertical damping,
        // gravity +3 in screen-down coordinates, and 0.89 horizontal inertia.
        if abs(velocity.dx) < 0.5 && direction == 0 {
            velocity.dx = 0
        }
        moveX(velocity.dx)
        moveY(velocity.dy)

        velocity.dy *= 0.85
        if !onGround { velocity.dy -= 3 }
        velocity.dx *= 0.89

        collectCoins()
        updatePowerUps(dt)
        updateFireballs(dt)
        updateEnemies(dt)

        marioAnimator?.update(dt: dt, velocityX: velocity.dx, velocityY: velocity.dy, onGround: onGround)
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
            enemyVerticalVelocities.append(0)
            enemyGrounded.append(false)
            enemyBaseY.append(enemy.position.y)
            enemyHorizontalVelocities.append(0)
            enemyTimers.append(0)
            enemyAnimators.append(kind == 2 || kind == 0 || kind == 1 || kind == 3
                ? EnemyAnimator(node: enemy, type: kind, winged: winged) : nil)
        }
    }

    /// Enemy.move() port: 1.75 px/tick horizontal speed, 0.89 inertia,
    /// Java gravity (2 or 0.6 for winged enemies), and red-koopa cliff avoidance.
    private func updateEnemies(_ dt: CGFloat) {
        var i = 0
        while i < enemies.count {
            let enemy = enemies[i]
            let kind = enemyKinds[i]
            var direction = enemyDirections[i]
            let winged = enemy.childNode(withName: "wings") != nil

            if kind == 5 {
                updateShell(at: i, dt: dt)
                i += 1
                continue
            }
            if kind == 6 {
                // Enemy.bumpCheck(): xa=-Mario.facing*2, ya=-5; flyDeath lasts 100 ticks.
                let javaYA = enemyVerticalVelocities[i]
                enemy.position.x += enemyHorizontalVelocities[i]
                enemy.position.y -= javaYA
                enemyVerticalVelocities[i] = javaYA * 0.95 + 1
                enemyTimers[i] += 1
                if enemyTimers[i] >= 100 {
                    removeEnemy(at: i)
                    continue
                }
                i += 1
                continue
            }
            if kind == 7 || kind == 8 {
                // Enemy.collideCheck(): stomped enemies remain in deadTime for 10 ticks.
                enemyTimers[i] += 1
                if enemyTimers[i] >= 10 {
                    if kind == 8 {
                        let shell = SKSpriteNode(
                            texture: SpriteSheet.texture(
                                named: "enemysheet",
                                cellSize: CGSize(width: 16, height: 16),
                                column: 4,
                                row: enemyDirections[i] == 0 ? 0 : 1
                            )
                        )
                        shell.size = CGSize(width: 16, height: 16)
                        shell.position = enemy.position
                        shell.zPosition = enemy.zPosition
                        worldNode.addChild(shell)
                        enemies[i] = shell
                        enemyKinds[i] = 5
                        enemyDirections[i] = 0
                        enemyVerticalVelocities[i] = -5
                        enemyHorizontalVelocities[i] = 0
                        enemyTimers[i] = 0
                        enemyGrounded[i] = false
                        enemyAnimators[i] = nil
                    } else {
                        removeEnemy(at: i)
                        continue
                    }
                }
                i += 1
                continue
            }
            if kind == 4 {
                updateFlowerEnemy(at: i)
                if damageInvulnerability <= 0 &&
                    abs(enemy.position.x - mario.position.x) < 14 &&
                    abs(enemy.position.y - mario.position.y) < 24 {
                    if isBigMario {
                        becomeSmallMario()
                        damageInvulnerability = 1.2
                    } else {
                        die()
                        return
                    }
                }
                enemyAnimators[i]?.update(dt: dt, direction: 1, onGround: true)
                i += 1
                continue
            }
            let halfW: CGFloat = 4
            let halfH: CGFloat = (kind == 0 || kind == 1) ? 12 : 6

            if direction == 0 { direction = 1 }
            let nextX = enemy.position.x + direction * 1.75
            let horizontalBlocked = collides(
                left: nextX - halfW, right: nextX + halfW,
                top: enemy.position.y + halfH, bottom: enemy.position.y - halfH,
                verticalMotion: 0
            )

            // Red koopas turn around at ledges; other enemies walk off.
            if horizontalBlocked || (kind == 0 && enemyGrounded[i] &&
                !hasGroundAhead(x: nextX + direction * halfW, y: enemy.position.y - halfH - 2)) {
                direction *= -1
                enemyDirections[i] = direction
            } else {
                enemy.position.x = nextX
            }

            let javaYA = enemyVerticalVelocities[i]
            let spriteDeltaY = -javaYA
            let nextY = enemy.position.y + spriteDeltaY
            let verticalBlocked = collides(
                left: enemy.position.x - halfW, right: enemy.position.x + halfW,
                top: nextY + halfH, bottom: nextY - halfH,
                verticalMotion: spriteDeltaY
            )
            if verticalBlocked {
                if spriteDeltaY < 0 {
                    let row = Int(floor((virtualHeight - (nextY - halfH)) / tile))
                    enemy.position.y = worldY(row: row) + tile + halfH
                    javaYA = 0
                    enemyGrounded[i] = true
                } else {
                    javaYA = 0
                    enemyGrounded[i] = false
                }
            } else {
                enemy.position.y = nextY
                enemyGrounded[i] = false
            }

            javaYA *= winged ? 0.95 : 0.85
            if enemyGrounded[i] && winged {
                javaYA = -10
            } else if !enemyGrounded[i] {
                javaYA += winged ? 0.6 : 2.0
            }
            enemyVerticalVelocities[i] = javaYA
            enemyAnimators[i]?.update(dt: dt, direction: direction, onGround: enemyGrounded[i])

            let marioDeltaY = mario.position.y - enemy.position.y
            let marioHeight: CGFloat = isBigMario ? 24 : 12
            let enemyHeight: CGFloat = (kind == 0 || kind == 1) ? 24 : 12
            // Java Enemy.collideCheck(): horizontal radius is width*2+4 (=12),
            // and vertical overlap is asymmetric because Java stores the feet anchor.
            let overlapsMario = abs(enemy.position.x - mario.position.x) < 12 &&
                marioDeltaY > -marioHeight && marioDeltaY < enemyHeight
            if damageInvulnerability <= 0 && overlapsMario {
                if velocity.dy < -0.1 && marioDeltaY >= 0 &&
                    (!onGround || !wasOnGround) && kind != 3 {
                    enemyKinds[i] = (kind == 0 || kind == 1) ? 8 : 7
                    enemyTimers[i] = 0
                    enemyDirections[i] = kind
                    enemyVerticalVelocities[i] = 0
                    enemyHorizontalVelocities[i] = 0
                    enemyGrounded[i] = false
                    enemy.size = CGSize(width: 16, height: 8)
                    enemy.position.y -= 4
                    enemy.removeAllChildren()
                    enemyAnimators[i] = nil
                    score += 100
                    velocity.dy = 15.2
                    sound.play(.stomp)
                    if enemy.parent == nil { continue }
                } else {
                    if isBigMario {
                        becomeSmallMario()
                        damageInvulnerability = 32.0 / 24.0
                        worldPauseTicks = 18
                        velocity.dy = 6.0
                        return
                    } else {
                        die()
                        return
                    }
                }
            }
            i += 1
        }
    }

    /// FlowerEnemy.move() port: fixed horizontal position and periodic vertical rise.
    private func updateFlowerEnemy(at index: Int) {
        let flower = enemies[index]
        let baseY = enemyBaseY[index]
        var javaYA = enemyVerticalVelocities[index]

        if flower.position.y <= baseY {
            flower.position.y = baseY
            enemyTimers[index] += 1
            if enemyTimers[index] > 40 && abs(mario.position.x - flower.position.x) > 24 {
                javaYA = -8
            } else {
                javaYA = 0
            }
        } else {
            enemyTimers[index] = 0
        }

        flower.position.y -= javaYA
        javaYA *= 0.9
        javaYA += 0.1
        enemyVerticalVelocities[index] = javaYA
    }

    /// Shell.move() port. Stationary shells are safe to touch and can be kicked;
    /// moving shells damage Mario and defeat other ordinary enemies.
    private func updateShell(at index: Int, dt: CGFloat) {
        let shell = enemies[index]
        var direction = enemyDirections[index]
        var javaYA = enemyVerticalVelocities[index]
        let halfW: CGFloat = 4
        let halfH: CGFloat = 6

        if direction != 0 {
            let nextX = shell.position.x + direction * 11
            if collides(
                left: nextX - halfW, right: nextX + halfW,
                top: shell.position.y + halfH, bottom: shell.position.y - halfH,
                verticalMotion: 0
            ) {
                direction = -direction
                enemyDirections[index] = direction
                sound.play(.stomp)
            } else {
                shell.position.x = nextX
            }
        }

        let spriteDeltaY = -javaYA
        let nextY = shell.position.y + spriteDeltaY
        if collides(
            left: shell.position.x - halfW, right: shell.position.x + halfW,
            top: nextY + halfH, bottom: nextY - halfH,
            verticalMotion: spriteDeltaY
        ) {
            if spriteDeltaY < 0 {
                let row = Int(floor((virtualHeight - (nextY - halfH)) / tile))
                shell.position.y = worldY(row: row) + tile + halfH
                javaYA = 0
                enemyGrounded[index] = true
            } else {
                javaYA = 0
                enemyGrounded[index] = false
            }
        } else {
            shell.position.y = nextY
            enemyGrounded[index] = false
        }
        javaYA *= 0.85
        if !enemyGrounded[index] { javaYA += 2 }
        enemyVerticalVelocities[index] = javaYA

        if abs(shell.position.x - mario.position.x) < 16 &&
            abs(shell.position.y - mario.position.y) < 20 {
            let marioIsStomping = velocity.dy < -0.1 &&
                mario.position.y > shell.position.y &&
                (!onGround || !wasOnGround)
            if marioIsStomping {
                if direction != 0 {
                    enemyDirections[index] = 0
                } else {
                    enemyDirections[index] = mario.position.x < shell.position.x ? 1 : -1
                }
                velocity.dy = 15.2
                sound.play(.stomp)
            } else if direction == 0 {
                enemyDirections[index] = mario.position.x < shell.position.x ? 1 : -1
                sound.play(.stomp)
            } else if damageInvulnerability <= 0 {
                if isBigMario {
                    becomeSmallMario()
                    damageInvulnerability = 1.2
                    velocity.dy = 6
                } else {
                    die()
                }
            }
        }

        if direction != 0 {
            var other = 0
            while other < enemies.count {
                if other == index || enemyKinds[other] == 5 {
                    other += 1
                    continue
                }
                if other < index {
                    other += 1
                    continue
                }
                let target = enemies[other]
                if abs(target.position.x - shell.position.x) < 15 &&
                    abs(target.position.y - shell.position.y) < 16 {
                    target.removeFromParent()
                    enemies.remove(at: other)
                    enemyKinds.remove(at: other)
                    enemyDirections.remove(at: other)
                    enemyVerticalVelocities.remove(at: other)
                    enemyGrounded.remove(at: other)
                    enemyBaseY.remove(at: other)
                    enemyHorizontalVelocities.remove(at: other)
                    enemyTimers.remove(at: other)
                    enemyAnimators.remove(at: other)
                    score += 200
                    if other < index { return }
                    continue
                }
                other += 1
            }
        }
    }

    private func hasGroundAhead(x: CGFloat, y: CGFloat) -> Bool {
        let column = Int(floor(x / tile))
        let row = Int(floor((virtualHeight - y) / tile))
        return level.isBlocking(column, row, verticalMotion: -1)
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
            coinTilePositions[ObjectIdentifier(coin)] = p
            coin.run(.repeatForever(.sequence([
                .scaleX(to: 0.25, duration: 0.28),
                .scaleX(to: 1, duration: 0.28)
            ])))
        }
    }

    private func collectCoins() {
        for coin in coins where coin.parent != nil {
            if abs(coin.position.x - mario.position.x) < 14 && abs(coin.position.y - mario.position.y) < 20 {
                let id = ObjectIdentifier(coin)
                coin.removeFromParent()
                if let tilePosition = coinTilePositions[id] {
                    _ = level.collectPickupable(x: tilePosition.x, y: tilePosition.y)
                    refreshTile(x: tilePosition.x, y: tilePosition.y)
                }
                coinTilePositions.removeValue(forKey: id)
                addCoin()
                score += 100
                sound.play(.coin)
            }
        }
    }

    private func moveX(_ amount: CGFloat) {
        if amount > 8 {
            moveX(8)
            moveX(amount - 8)
            return
        }
        if amount < -8 {
            moveX(-8)
            moveX(amount + 8)
            return
        }

        let halfW: CGFloat = 4
        let hitHalfH: CGFloat = isBigMario ? 12 : 6
        let hitOffset: CGFloat = isBigMario ? -4 : -2
        let hitCenterY = mario.position.y + hitOffset
        let nextX = mario.position.x + amount
        let sampleYs = [
            hitCenterY + hitHalfH - 1,
            hitCenterY,
            hitCenterY - hitHalfH + 1
        ]

        if amount > 0 {
            let edgeX = nextX + halfW
            if sampleYs.contains(where: { tileBlocks(worldX: edgeX, worldY: $0, motionY: 0) }) {
                let column = Int(floor(edgeX / tile))
                mario.position.x = CGFloat(column) * tile - halfW - 0.1
                velocity.dx = 0
                sliding = true
                return
            }
        } else if amount < 0 {
            let edgeX = nextX - halfW
            if sampleYs.contains(where: { tileBlocks(worldX: edgeX, worldY: $0, motionY: 0) }) {
                let column = Int(floor(edgeX / tile))
                mario.position.x = CGFloat(column + 1) * tile + halfW + 0.1
                velocity.dx = 0
                sliding = true
                return
            }
        }
        sliding = false
        mario.position.x = min(CGFloat(level.width) * tile, max(4, nextX))
    }

    private func moveY(_ amount: CGFloat) {
        if amount > 8 {
            moveY(8)
            moveY(amount - 8)
            return
        }
        if amount < -8 {
            moveY(-8)
            moveY(amount + 8)
            return
        }

        let halfW: CGFloat = 4
        let hitHalfH: CGFloat = isBigMario ? 12 : 6
        let hitOffset: CGFloat = isBigMario ? -4 : -2
        let nextY = mario.position.y + amount
        let hitCenterY = nextY + hitOffset
        let sampleXs = [
            mario.position.x - halfW,
            mario.position.x,
            mario.position.x + halfW
        ]

        if amount < 0 {
            let bottom = hitCenterY - hitHalfH
            if sampleXs.contains(where: { tileBlocks(worldX: $0, worldY: bottom, motionY: amount) }) ||
                sampleXs.contains(where: { tileBlocks(worldX: $0, worldY: bottom - 1, motionY: amount) }) {
                let row = Int(floor((virtualHeight - bottom) / tile))
                mario.position.y = worldY(row: row) + tile + hitHalfH - hitOffset
                velocity.dy = 0
                onGround = true
            } else {
                mario.position.y = nextY
                onGround = false
            }
        } else if amount > 0 {
            let top = hitCenterY + hitHalfH
            if sampleXs.contains(where: { tileBlocks(worldX: $0, worldY: top, motionY: amount) }) {
                let row = Int(floor((virtualHeight - top) / tile))
                mario.position.y = worldY(row: row) - hitHalfH - hitOffset - 0.1
                velocity.dy = 0
                for x in sampleXs.map({ Int(floor($0 / tile)) }) {
                    if level.isBlocking(x, row, verticalMotion: amount) {
                        hitBlock(x: x, y: row)
                        break
                    }
                }
            } else {
                mario.position.y = nextY
            }
        } else {
            mario.position.y = nextY
            onGround = false
        }
    }

    private func tileBlocks(worldX: CGFloat, worldY: CGFloat, motionY: CGFloat) -> Bool {
        let column = Int(floor(worldX / tile))
        let row = Int(floor((virtualHeight - worldY) / tile))
        return level.isBlocking(column, row, verticalMotion: motionY)
    }

    private func checkQuestionBlocks() {
        guard velocity.dy > 0 else { return }
        let hitOffset: CGFloat = isBigMario ? -4 : -2
        let hitHalfH: CGFloat = isBigMario ? 12 : 6
        let top = mario.position.y + hitOffset + hitHalfH
        let row = Int(floor((virtualHeight - top) / tile))
        let left = Int(floor((mario.position.x - 4) / tile))
        let right = Int(floor((mario.position.x + 4) / tile))
        for x in left...right { hitBlock(x: x, y: row) }
    }

    /// Mirrors LevelScene.bump(): bumpable blocks become tile 4; special
    /// blocks release a power-up, ordinary bumpable blocks release a coin,
    /// and breakable bricks disappear only when Mario is large.
    private func removeEnemy(at index: Int) {
        enemies[index].removeFromParent()
        enemies.remove(at: index)
        enemyKinds.remove(at: index)
        enemyDirections.remove(at: index)
        enemyVerticalVelocities.remove(at: index)
        enemyGrounded.remove(at: index)
        enemyBaseY.remove(at: index)
        enemyHorizontalVelocities.remove(at: index)
        enemyTimers.remove(at: index)
        enemyAnimators.remove(at: index)
    }

    /// LevelScene.bumpInto() notifies every enemy whose feet are aligned
    /// with the tile immediately above the block.
    private func bumpEnemies(fromBlockX x: Int, fromBlockY y: Int) {
        let tileLeft = CGFloat(x) * tile
        let tileRight = tileLeft + tile
        for i in enemies.indices {
            guard enemyKinds[i] != 5 && enemyKinds[i] != 6 else { continue }
            let enemy = enemies[i]
            let enemyLeft = enemy.position.x - enemy.size.width / 2
            let enemyRight = enemy.position.x + enemy.size.width / 2
            // Java Enemy.bumpCheck() compares yTile with (int)((enemy.y - 1) / 16).
            let javaY = virtualHeight - enemy.position.y
            let enemyRow = Int(floor((javaY - 1) / tile))
            guard enemyRight > tileLeft && enemyLeft < tileRight && enemyRow == y else { continue }
            enemyKinds[i] = 6
            enemyDirections[i] = mario.xScale < 0 ? 1 : -1
            enemyHorizontalVelocities[i] = -enemyDirections[i] * 2
            enemyVerticalVelocities[i] = -5
            enemyTimers[i] = 0
            enemyGrounded[i] = false
            enemy.removeAllChildren()
            enemy.color = .white
            enemy.zRotation = .pi
            enemyAnimators[i] = nil
        }
    }

    private func hitBlock(x: Int, y: Int) {
        let flags = level.behavior(at: x, y)
        guard flags & 0b0011_0000 != 0 else { return }

        // Java LevelScene.bump() calls bumpInto(x, y - 1) before changing the block.
        bumpEnemies(fromBlockX: x, fromBlockY: y - 1)
        if level.collectPickupable(x: x, y: y - 1) {
            refreshTile(x: x, y: y - 1)
            addCoin()
            score += 100
            spawnCoinPop(x: x, y: y - 1)
            sound.play(.coin)
        }
        guard let result = level.bumpBlock(x: x, y: y, canBreak: isBigMario) else { return }
        let k = key(x, y)
        switch result {
        case .item:
            refreshTile(x: x, y: y)
            let position = tileCenter(x: x, row: y)
            spawnPowerUp(at: position, kind: isBigMario ? "flower" : "mushroom")
            sound.play(.sprout)
        case .coin:
            refreshTile(x: x, y: y)
            addCoin()
            spawnCoinPop(x: x, y: y)
            sound.play(.coin)
        case .broken:
            refreshTile(x: x, y: y)
            spawnBrickFragments(at: tileCenter(x: x, row: y))
            sound.play(.block)
        case .bumped:
            // Small Mario can bump a brick but cannot break it.
            spawnBlockBump(at: tileCenter(x: x, row: y))
            sound.play(.block)
        }
        usedBlocks.insert(k)
        if result == .item || result == .coin {
            questionNodes.removeValue(forKey: k)
        }
        score += result == .coin ? 200 : (result == .item ? 200 : 0)
    }

    private func makeTileNode(tileID: UInt8) -> SKSpriteNode {
        let value = Int(tileID)
        let node: SKSpriteNode
        if let texture = SpriteSheet.texture(named: "mapsheet", cellSize: CGSize(width: 16, height: 16), column: value % 16, row: value / 16) {
            node = SKSpriteNode(texture: texture)
        } else {
            node = SKSpriteNode(color: .brown, size: CGSize(width: tile, height: tile))
        }
        node.size = CGSize(width: tile, height: tile)
        return node
    }

    private func refreshTile(x: Int, y: Int) {
        let k = key(x, y)
        tileNodes[k]?.removeFromParent()
        if let oldQuestion = questionNodes[k] {
            oldQuestion.removeFromParent()
            questionNodes.removeValue(forKey: k)
        }
        guard level.tileIDs[x][y] != 0 else {
            tileNodes.removeValue(forKey: k)
            questionNodes.removeValue(forKey: k)
            return
        }
        let node = makeTileNode(tileID: level.tileIDs[x][y])
        node.position = tileCenter(x: x, row: y)
        node.zPosition = 2
        worldNode.addChild(node)
        tileNodes[k] = node
        questionNodes[k] = node
    }

    private func addCoin() {
        collectedCoins += 1
        if collectedCoins >= 100 {
            collectedCoins -= 100
            lives = min(99, lives + 1)
            sound.play(.oneUp)
        }
    }

    private func spawnCoinPop(x: Int, y: Int) {
        let coin = SKShapeNode(ellipseOf: CGSize(width: 8, height: 13))
        coin.fillColor = .yellow
        coin.strokeColor = .white
        coin.position = tileCenter(x: x, row: y)
        coin.zPosition = 30
        worldNode.addChild(coin)
        coin.run(.sequence([
            .moveBy(x: 0, y: 25, duration: 0.22),
            .fadeOut(withDuration: 0.12),
            .removeFromParent()
        ]))
    }

    private func spawnBlockBump(at position: CGPoint) {
        let bump = SKShapeNode(rectOf: CGSize(width: 15, height: 3))
        bump.fillColor = .white
        bump.strokeColor = .clear
        bump.position = position
        bump.zPosition = 25
        worldNode.addChild(bump)
        bump.run(.sequence([
            .moveBy(x: 0, y: 3, duration: 0.06),
            .moveBy(x: 0, y: -3, duration: 0.08),
            .removeFromParent()
        ]))
    }

    private func spawnBrickFragments(at position: CGPoint) {
        for x in [-1, 1] {
            for y in [-1, 1] {
                let piece = SKShapeNode(rectOf: CGSize(width: 7, height: 7))
                piece.fillColor = SKColor(red: 0.62, green: 0.30, blue: 0.12, alpha: 1)
                piece.strokeColor = .clear
                piece.position = position
                piece.zPosition = 35
                worldNode.addChild(piece)
                piece.run(.sequence([
                    .group([
                        .moveBy(x: CGFloat(x) * 13, y: CGFloat(y) * 17, duration: 0.35),
                        .fadeOut(withDuration: 0.35)
                    ]),
                    .removeFromParent()
                ]))
            }
        }
    }

    private func spawnPowerUp(at position: CGPoint, kind: String) {
        let power: SKSpriteNode
        let column = kind == "flower" ? 1 : 0
        if let texture = SpriteSheet.texture(named: "itemsheet", cellSize: CGSize(width: 16, height: 16), column: column, row: 0) {
            power = SKSpriteNode(texture: texture)
        } else {
            power = SKSpriteNode(color: kind == "flower" ? .yellow : .red, size: CGSize(width: 16, height: 16))
        }
        power.size = CGSize(width: 16, height: 16)
        power.position = CGPoint(x: position.x, y: position.y + 4)
        power.zPosition = 12
        worldNode.addChild(power)
        powerUps.append(power)
        let id = ObjectIdentifier(power)
        powerUpKinds[id] = kind
        powerUpVelocity[id] = .zero
        powerUpDirections[id] = 1
        powerUpTicks[id] = 0
    }

    /// Mushroom/FireFlower emergence and movement use the original 24 Hz tick units.
    private func updatePowerUps(_ dt: CGFloat) {
        var i = 0
        while i < powerUps.count {
            let p = powerUps[i]
            let id = ObjectIdentifier(p)
            let kind = powerUpKinds[id] ?? "mushroom"
            var ticks = powerUpTicks[id] ?? 0
            var v = powerUpVelocity[id] ?? CGVector(dx: 0, dy: -1)

            if ticks < 9 {
                p.position.y += 1
                ticks += 1
                powerUpTicks[id] = ticks
                i += 1
                continue
            }

            if kind == "mushroom" {
                let direction = powerUpDirections[id] ?? 1
                let nextX = p.position.x + direction * 1.75
                if collides(left: nextX - 4, right: nextX + 4,
                    top: p.position.y + 12, bottom: p.position.y - 12) {
                    powerUpDirections[id] = -direction
                } else {
                    p.position.x = nextX
                }

                let nextY = p.position.y + v.dy
                if collides(left: p.position.x - 4, right: p.position.x + 4,
                    top: nextY + 12, bottom: nextY - 12, verticalMotion: v.dy) {
                    if v.dy < 0 {
                        let row = Int(floor((virtualHeight - (nextY - 12)) / tile))
                        p.position.y = worldY(row: row) + tile + 12
                    }
                    v.dy = 0
                } else {
                    p.position.y = nextY
                }
                v.dy *= 0.85
                if !collides(left: p.position.x - 4, right: p.position.x + 4,
                    top: p.position.y + 13, bottom: p.position.y + 11) {
                    v.dy -= 2
                }
                powerUpVelocity[id] = v
            }

            if abs(p.position.x - mario.position.x) < 16 &&
                p.position.y - mario.position.y > -12 &&
                p.position.y - mario.position.y < (isBigMario ? 24 : 12) {
                p.removeFromParent()
                powerUps.remove(at: i)
                powerUpKinds.removeValue(forKey: id)
                powerUpVelocity.removeValue(forKey: id)
                powerUpDirections.removeValue(forKey: id)
                powerUpTicks.removeValue(forKey: id)
                if kind == "flower" { becomeFireMario() } else { becomeBigMario() }
                worldPauseTicks = 18
                score += 1000
                i += 1
                continue
            }
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
            for enemyIndex in enemies.indices {
                let enemy = enemies[enemyIndex]
                guard abs(enemy.position.x - b.position.x) < 14 &&
                    abs(enemy.position.y - b.position.y) < 16 else { continue }

                if enemyKinds[enemyIndex] == 3 {
                    // Java's spiky enemy survives fireballs; the fireball is consumed.
                    hit = true
                    break
                }
                if enemyKinds[enemyIndex] == 5 {
                    // A stationary shell is kicked by a fireball; a moving shell absorbs it.
                    if enemyDirections[enemyIndex] == 0 {
                        enemyDirections[enemyIndex] = (fireballVelocity[id]?.dx ?? 1) >= 0 ? 1 : -1
                    }
                    hit = true
                    break
                }

                enemy.removeFromParent()
                enemies.remove(at: enemyIndex)
                enemyKinds.remove(at: enemyIndex)
                enemyDirections.remove(at: enemyIndex)
                enemyVerticalVelocities.remove(at: enemyIndex)
                enemyGrounded.remove(at: enemyIndex)
                enemyBaseY.remove(at: enemyIndex)
                enemyHorizontalVelocities.remove(at: enemyIndex)
                enemyTimers.remove(at: enemyIndex)
                enemyAnimators.remove(at: enemyIndex)
                score += 200
                sound.play(.stomp)
                hit = true
                break
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
        marioAnimator = MarioAnimator(node: mario, small: true)
        if let texture = SpriteSheet.texture(named: "smallmariosheet", cellSize: CGSize(width: 16, height: 16), column: 0, row: 0) {
            mario.texture = texture
        }
    }

    private func collides(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat, verticalMotion: CGFloat? = nil) -> Bool {
        let minX = Int(floor(left / tile))
        let maxX = Int(floor(right / tile))
        let minY = Int(floor((virtualHeight - top) / tile))
        let maxY = Int(floor((virtualHeight - bottom) / tile))
        for x in minX...maxX {
            for y in minY...maxY where level.isBlocking(x, y, verticalMotion: verticalMotion) { return true }
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
