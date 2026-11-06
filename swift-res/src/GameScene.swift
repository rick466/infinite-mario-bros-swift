import SpriteKit
import UIKit

final class GameScene: SKScene {
    private let virtualWidth: CGFloat = 320
    private let virtualHeight: CGFloat = 240

    private var mario = SKSpriteNode()
    private var leftHeld = false
    private var rightHeld = false
    private var jumpHeld = false

    private var velocityY: CGFloat = 0
    private let gravity: CGFloat = -900
    private let groundY: CGFloat = 48

    override func didMove(to view: SKView) {
        scaleMode = .aspectFit
        backgroundColor = .black
        size = CGSize(width: virtualWidth, height: virtualHeight)
        buildInitialScene()
    }

    private func buildInitialScene() {
        removeAllChildren()

        let sky = SKSpriteNode(
            color: SKColor(red: 0.40, green: 0.65, blue: 0.95, alpha: 1),
            size: size
        )
        sky.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sky.zPosition = -10
        addChild(sky)

        let ground = SKSpriteNode(
            color: SKColor(red: 0.45, green: 0.28, blue: 0.12, alpha: 1),
            size: CGSize(width: size.width, height: 32)
        )
        ground.position = CGPoint(x: size.width / 2, y: 16)
        addChild(ground)

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
        mario.position = CGPoint(x: 80, y: groundY)
        mario.zPosition = 10
        addChild(mario)

        addTouchControls()
    }

    private func addTouchControls() {
        let controls = [
            ("LEFT", CGPoint(x: 42, y: 38), 0),
            ("RIGHT", CGPoint(x: 98, y: 38), 1),
            ("JUMP", CGPoint(x: size.width - 58, y: 38), 2)
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

            addChild(node)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            handleTouch(touch, pressed: true)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            handleTouch(touch, pressed: true)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            handleTouch(touch, pressed: false)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            handleTouch(touch, pressed: false)
        }
    }

    private func handleTouch(_ touch: UITouch, pressed: Bool) {
        let p = touch.location(in: self)

        if p.x < 72 && p.y < 72 {
            leftHeld = pressed
        } else if p.x < 128 && p.y < 72 {
            rightHeld = pressed
        } else if p.x > size.width - 120 && p.y < 72 {
            jumpHeld = pressed
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat = 1.0 / 60.0
        let speed: CGFloat = 110

        if leftHeld { mario.position.x -= speed * dt }
        if rightHeld { mario.position.x += speed * dt }

        if jumpHeld && mario.position.y <= groundY + 0.1 {
            velocityY = 330
        }

        velocityY += gravity * dt
        mario.position.y += velocityY * dt

        if mario.position.y < groundY {
            mario.position.y = groundY
            velocityY = 0
        }

        mario.position.x = min(max(mario.position.x, 16), size.width - 16)
    }
}
