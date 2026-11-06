import Foundation

struct GameLevel {
    let width: Int
    let height: Int
    var tiles: [[Bool]]
    var tileIDs: [[UInt8]]
    let questionBlockPositions: [SIMD2<Int>]
    let coinPositions: [SIMD2<Int>]
    let enemyPositions: [SIMD2<Int>]
    let enemyTypes: [Int]
    let enemyWinged: [Bool]
    let exitX: Int
    let exitY: Int

    init(width: Int = 320, height: Int = 15, stage: Int = 0) {
        let types: [LevelGenerator.LevelType] = [.overground, .underground, .castle]
        let difficulty = min(3, stage + 1)
        let generated = LevelGenerator.make(
            width: width,
            height: height,
            seed: 0x4D4152494F &+ (UInt64(stage) &* 0x9E3779B97F4A7C15),
            difficulty: difficulty,
            type: types[min(stage, types.count - 1)]
        )
        self.width = generated.width
        self.height = generated.height
        self.tileIDs = generated.tileIDs
        self.tiles = generated.tileIDs.map { column in
            column.map { tileID in
                (Self.tileBehaviors[Int(tileID)] & 0b0000_0111) != 0
            }
        }
        self.questionBlockPositions = generated.tileIDs.enumerated().flatMap { x, column in
            column.enumerated().compactMap { y, tileID in
                (Self.tileBehaviors[Int(tileID)] & 0b0011_0000) != 0
                    ? SIMD2<Int>(x, y) : nil
            }
        }
        self.coinPositions = generated.tileIDs.enumerated().flatMap { x, column in
            column.enumerated().compactMap { y, tileID in
                (Self.tileBehaviors[Int(tileID)] & 0b0100_0000) != 0
                    ? SIMD2<Int>(x, y) : nil
            }
        }
        self.enemyPositions = generated.enemies.map { SIMD2($0.x, $0.y) }
        self.enemyTypes = generated.enemies.map(\.type)
        self.enemyWinged = generated.enemies.map(\.winged)
        self.exitX = generated.exitX
        self.exitY = generated.exitY
    }

    enum BlockHit { case item, coin, broken, bumped }

    func behavior(at x: Int, _ y: Int) -> UInt8 {
        guard x >= 0, x < width, y >= 0, y < height else { return 0 }
        return Self.tileBehaviors[Int(tileIDs[x][y])]
    }

    mutating func bumpBlock(x: Int, y: Int, canBreak: Bool) -> BlockHit? {
        let flags = behavior(at: x, y)
        if flags & 0b0001_0000 != 0 { // BIT_BUMPABLE
            tileIDs[x][y] = 4 // Java LevelScene.bump() replaces it with used block.
            tiles[x][y] = true
            return flags & 0b0000_1000 != 0 ? .item : .coin
        }
        if flags & 0b0010_0000 != 0 { // BIT_BREAKABLE
            if canBreak {
                tileIDs[x][y] = 0
                tiles[x][y] = false
                return .broken
            }
            return .bumped
        }
        return nil
    }

    mutating func collectPickupable(x: Int, y: Int) -> Bool {
        guard behavior(at: x, y) & 0b0100_0000 != 0 else { return false }
        tileIDs[x][y] = 0
        tiles[x][y] = false
        return true
    }

    private static let tileBehaviors: [UInt8] = {
        if let url = Bundle.module.url(forResource: "tiles", withExtension: "dat"),
           let data = try? Data(contentsOf: url), data.count >= 256 {
            return Array(data.prefix(256))
        }
        // Exact 256-byte TILE_BEHAVIORS table from the original Java res/tiles.dat.
        let encoded = "ABQcAIKCgoICAgICAgCKAKKSmqKSkpqSAgACAgIAAgDAwMDAAAAAAAICAAAAAAIAAAAAAAAAAAACAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAgIAAQEBAAICAgACAgIAAgACAAAAAAACAgIAAgICAAICAgAAAAAAAgICAAICAgACAgIAAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="
        guard let data = Data(base64Encoded: encoded), data.count == 256 else {
            return (0..<256).map { $0 == 0 ? 0 : 2 }
        }
        return Array(data)
    }()

    func isPickupable(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        return (Self.tileBehaviors[Int(tileIDs[x][y])] & 0b0100_0000) != 0
    }

    func isSolid(_ x: Int, _ y: Int) -> Bool {
        guard y >= 0 else { return false }
        let safeX = min(max(x, 0), width - 1)
        let safeY = min(y, height - 1)
        return (Self.tileBehaviors[Int(tileIDs[safeX][safeY])] & 0b0000_0111) != 0
    }

    /// verticalMotion is expressed in SpriteKit coordinates (up is positive).
    /// Java's Level.isBlocking uses screen coordinates (down is positive).
    func isBlocking(_ x: Int, _ y: Int, verticalMotion: CGFloat? = nil) -> Bool {
        guard y >= 0 else { return false }
        let safeX = min(max(x, 0), width - 1)
        let safeY = min(y, height - 1)
        let flags = Self.tileBehaviors[Int(tileIDs[safeX][safeY])]
        if flags & 0b0000_0010 != 0 { return true } // BLOCK_ALL
        guard let verticalMotion else {
            return (flags & 0b0000_0111) != 0
        }
        let javaMotionY = -verticalMotion
        if javaMotionY > 0 && flags & 0b0000_0001 != 0 { return true } // BLOCK_UPPER
        if javaMotionY < 0 && flags & 0b0000_0100 != 0 { return true } // BLOCK_LOWER
        return false
    }
}
