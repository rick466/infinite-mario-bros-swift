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

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: virtualWidth / 2, y: virtualHeight / 2)
        addChild(cameraNode)
        camera = cameraNode
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
        let dt = min(CGFloat(1.0 / 60.0),
                      CGFloat(currentTime - (lastTime == 0 ? currentTime : lastTime)))
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
        updateCamera()
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
                let row = Int(floor(bottom / tile))
                mario.position.y = CGFloat(row + 1) * tile + halfH
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
                mario.position.y = CGFloat(floor(top / tile)) * tile - halfH - 0.1
                velocity.dy = 0
                return
            }
        }

        mario.position.y = newY

        if mario.position.y < -40 {
            mario.position = CGPoint(x: 48, y: 160)
            velocity = .zero
        }
    }

    private func collides(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat) -> Bool {
        let minX = Int(floor(left / tile))
        let maxX = Int(floor(right / tile))
        let minY = Int(floor((virtualHeight - top) / tile))
        let maxY = Int(floor((virtualHeight - bottom) / tile))

        for x in minX...maxX {
            for y in minY...maxY {
                if level.isSolid(x, y) { return true }
            }
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
}
