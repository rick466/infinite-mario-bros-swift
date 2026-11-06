import Foundation

/// Simplified Swift port of the original Java LevelGenerator.
/// The tile map is intentionally independent from SpriteKit so it can be
/// used by the iPad game and expanded toward the original generator.
struct LevelGenerator {
    enum LevelType {
        case overground
        case underground
        case castle
    }

    struct Result {
        let width: Int
        let height: Int
        var tiles: [[Bool]]
        var questionBlocks: [SIMD2<Int>]
        var coins: [SIMD2<Int>]
        var enemies: [SIMD2<Int>]
    }

    static func make(width: Int = 320, height: Int = 15, seed: UInt64 = 0x4D4152494F, difficulty: Int = 1, type: LevelType = .overground) -> Result {
        var rng = SeededRandom(seed: seed)
        var tiles = Array(repeating: Array(repeating: false, count: height), count: width)
        var questions: [SIMD2<Int>] = []
        var coins: [SIMD2<Int>] = []
        var enemies: [SIMD2<Int>] = []

        func floorHeight() -> Int {
            max(7, height - 1 - rng.nextInt(upperBound: 4))
        }

        func fillFloor(_ start: Int, _ end: Int, _ floor: Int) {
            guard start < end else { return }
            for x in start..<min(end, width) {
                for y in floor..<height {
                    tiles[x][y] = true
                }
            }
        }

        var x = 0
        fillFloor(0, 12, floorHeight())
        x = 12

        while x < width - 24 {
            let segment = rng.nextInt(upperBound: 5)

            switch segment {
            case 0:
                let length = min(rng.nextInt(upperBound: 9) + 5, width - x)
                let floor = floorHeight()
                fillFloor(x, x + length, floor)

                if length > 6 {
                    let count = max(1, difficulty)
                    for _ in 0..<count {
                        let px = x + 2 + rng.nextInt(upperBound: max(2, length - 4))
                        let py = max(2, floor - 1)
                        enemies.append(.init(px, py))
                    }

                    if floor > 3 {
                        let start = x + 2
                        let end = max(start + 1, x + length - 2)
                        for px in start..<end {
                            if rng.nextInt(upperBound: 3) == 0 {
                                questions.append(.init(px, floor - 2))
                            }
                        }
                    }
                }
                x += length

            case 1:
                let length = min(rng.nextInt(upperBound: 8) + 6, width - x)
                let floor = floorHeight()
                fillFloor(x, x + length, floor)

                if floor > 5 {
                    let platformHeight = floor - 3
                    let start = x + 2
                    let end = max(start + 1, x + length - 2)
                    for px in start..<end {
                        tiles[px][platformHeight] = true
                        if rng.nextInt(upperBound: 4) == 0 {
                            coins.append(.init(px, platformHeight - 1))
                        }
                    }
                }
                x += length

            case 2:
                let length = min(rng.nextInt(upperBound: 7) + 5, width - x)
                let floor = floorHeight()
                fillFloor(x, x + length, floor)

                var tubeX = x + 1
                while tubeX < x + length - 1 {
                    let tubeHeight = max(3, floor - rng.nextInt(upperBound: 3) - 2)
                    if rng.nextInt(upperBound: 11) <= difficulty + 1 {
                        enemies.append(.init(tubeX, tubeHeight - 1))
                    }
                    for tx in tubeX...min(tubeX + 1, x + length - 1) {
                        for ty in tubeHeight..<floor {
                            tiles[tx][ty] = true
                        }
                    }
                    tubeX += rng.nextInt(upperBound: 4) + 3
                }
                x += length

            case 3:
                let side = rng.nextInt(upperBound: 4) + 2
                let gap = rng.nextInt(upperBound: 3) + 2
                let length = min(side * 2 + gap, width - x)
                let floor = floorHeight()

                fillFloor(x, x + side, floor)
                fillFloor(x + side + gap, x + length, floor)

                for px in x + side..<min(x + side + gap, width) {
                    coins.append(.init(px, max(2, floor - 3)))
                }
                x += length

            default:
                let length = min(rng.nextInt(upperBound: 9) + 3, width - x)
                let floor = floorHeight()
                fillFloor(x, x + length, floor)

                if floor > 3 {
                    let cannonX = x + 1 + rng.nextInt(upperBound: max(1, length - 2))
                    for y in max(2, floor - 4)..<floor {
                        tiles[cannonX][y] = true
                    }
                }
                x += length
            }
        }

        let exitFloor = floorHeight()
        fillFloor(x, width, exitFloor)

        // Add a small safe starting area.
        for px in 0..<min(14, width) {
            for py in max(0, exitFloor - 1)..<height {
                tiles[px][py] = true
            }
        }

        if type != .overground {
            for px in 4..<width {
                let ceiling = rng.nextInt(upperBound: 4)
                for py in 0...ceiling {
                    tiles[px][py] = true
                }
            }
        }

        // Convert a few empty areas above the ground into the familiar
        // question-block/coin pattern used by the original game.
        for px in stride(from: 18, to: width - 8, by: 31) {
            let floor = firstSolidRow(in: tiles, x: px, height: height)
            if floor > 4 {
                questions.append(.init(px, floor - 3))
                coins.append(.init(px, floor - 2))
            }
        }

        return Result(
            width: width,
            height: height,
            tiles: tiles,
            questionBlocks: questions,
            coins: coins,
            enemies: enemies
        )
    }

    private static func firstSolidRow(in tiles: [[Bool]], x: Int, height: Int) -> Int {
        guard x >= 0, x < tiles.count else { return height - 1 }
        for y in 0..<height where tiles[x][y] {
            return y
        }
        return height - 1
    }
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xA5A5A5A5A5A5A5A5 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextInt(upperBound: Int) -> Int {
        guard upperBound > 1 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }
}
