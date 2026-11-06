import Foundation

struct GameLevel {
    let width: Int
    let height: Int
    var tiles: [[Bool]]
    let questionBlockPositions: [SIMD2<Int>]
    let coinPositions: [SIMD2<Int>]
    let enemyPositions: [SIMD2<Int>]

    init(width: Int = 320, height: Int = 15, seed: UInt64 = 0x4D4152494F) {
        let generated = LevelGenerator.make(
            width: width,
            height: height,
            seed: seed,
            difficulty: 1,
            type: .overground
        )

        self.width = generated.width
        self.height = generated.height
        self.tiles = generated.tiles
        self.questionBlockPositions = generated.questionBlocks
        self.coinPositions = generated.coins
        self.enemyPositions = generated.enemies
    }

    func isSolid(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else {
            return y < 0 || x < 0 || x >= width
        }
        return tiles[x][y]
    }
}
