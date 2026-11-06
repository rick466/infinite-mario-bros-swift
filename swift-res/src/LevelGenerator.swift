import Foundation

/// Port of the original Infinite Mario Bros. Java LevelGenerator.
/// Random number generation follows java.util.Random's 48-bit LCG so a seed
/// produces the same zone decisions and tile layout as the Java version.
struct LevelGenerator {
    enum LevelType: Int { case overground = 0, underground = 1, castle = 2 }

    struct EnemySpawn {
        let x: Int
        let y: Int
        let type: Int
        let winged: Bool
    }

    struct Result {
        let width: Int
        let height: Int
        var tileIDs: [[UInt8]]
        var enemies: [EnemySpawn]
        var exitX: Int
        var exitY: Int

        var tiles: [[Bool]] {
            tileIDs.map { column in column.map { $0 != 0 } }
        }
        var questionBlocks: [SIMD2<Int>] {
            var result: [SIMD2<Int>] = []
            for x in 0..<width {
                for y in 0..<height where tileIDs[x][y] == 34 {
                    result.append(.init(x, y))
                }
            }
            return result
        }
        var coins: [SIMD2<Int>] { [] }
    }

    private static let ground: UInt8 = 145
    private var width: Int
    private var height: Int
    private var type: LevelType
    private var difficulty: Int
    private var rng: JavaRandom
    private var map: [[UInt8]]
    private var enemySpawns: [EnemySpawn] = []
    private var odds = [Int](repeating: 0, count: 5)
    private var totalOdds = 0

    static func make(width: Int = 320, height: Int = 15, seed: UInt64, difficulty: Int, type: LevelType) -> Result {
        var generator = LevelGenerator(width: width, height: height, seed: seed, difficulty: difficulty, type: type)
        return generator.generate()
    }

    private init(width: Int, height: Int, seed: UInt64, difficulty: Int, type: LevelType) {
        self.width = width
        self.height = height
        self.difficulty = difficulty
        self.type = type
        self.rng = JavaRandom(seed: seed)
        self.map = Array(repeating: Array(repeating: 0, count: height), count: width)
    }

    private mutating func generate() -> Result {
        odds = [20, 10, 2 + difficulty, 2 * difficulty, -10 + 5 * difficulty]
        if type != .overground { odds[1] = 0 }
        for i in odds.indices {
            odds[i] = max(0, odds[i])
            totalOdds += odds[i]
            odds[i] = totalOdds - odds[i]
        }

        var length = buildStraight(0, width, safe: true)
        while length < width - 64 {
            length += buildZone(length, width - length)
        }

        let floor = height - 1 - rng.nextInt(4)
        let exitX = length + 8
        let exitY = floor
        if length < width {
            for x in length..<width {
                for y in floor..<height { set(x, y, Self.ground) }
            }
        }

        if type == .castle || type == .underground {
            var ceiling = 0
            var run = 0
            for x in 0..<width {
                if run <= 0 && x > 4 {
                    ceiling = rng.nextInt(4)
                    run = rng.nextInt(4) + 4
                }
                run -= 1
                for y in 0..<height where (x > 4 && y <= ceiling) || x < 1 {
                    set(x, y, Self.ground)
                }
            }
        }
        fixWalls()
        return Result(width: width, height: height, tileIDs: map, enemies: enemySpawns, exitX: exitX, exitY: exitY)
    }

    private mutating func buildZone(_ x: Int, _ maxLength: Int) -> Int {
        let roll = rng.nextInt(max(1, totalOdds))
        var selected = 0
        for i in odds.indices where odds[i] <= roll { selected = i }
        switch selected {
        case 0: return buildStraight(x, maxLength, safe: false)
        case 1: return buildHillStraight(x, maxLength)
        case 2: return buildTubes(x, maxLength)
        case 3: return buildJump(x, maxLength)
        default: return buildCannons(x, maxLength)
        }
    }

    private mutating func buildJump(_ xo: Int, _ maxLength: Int) -> Int {
        let js = rng.nextInt(4) + 2
        let jl = rng.nextInt(2) + 2
        let length = min(js * 2 + jl, maxLength)
        let stairs = rng.nextInt(3) == 0
        let floor = height - 1 - rng.nextInt(4)
        for x in xo..<min(width, xo + length) where x < xo + js || x > xo + length - js - 1 {
            for y in 0..<height {
                if y >= floor { set(x, y, Self.ground) }
                else if stairs {
                    let threshold = x < xo + js ? floor - (x - xo) + 1 : floor - ((xo + length) - x) + 2
                    if y >= threshold { set(x, y, 9) }
                }
            }
        }
        return length
    }

    private mutating func buildCannons(_ xo: Int, _ maxLength: Int) -> Int {
        let length = min(rng.nextInt(10) + 2, maxLength)
        let floor = height - 1 - rng.nextInt(4)
        var cannonX = xo + 1 + rng.nextInt(4)
        for x in xo..<min(width, xo + length) {
            if x > cannonX { cannonX += 2 + rng.nextInt(4) }
            if cannonX == xo + length - 1 { cannonX += 10 }
            let cannonHeight = floor - rng.nextInt(4) - 1
            for y in 0..<height {
                if y >= floor { set(x, y, Self.ground) }
                else if x == cannonX && y >= cannonHeight {
                    set(x, y, UInt8(14 + (y == cannonHeight ? 0 : (y == cannonHeight + 1 ? 16 : 32))))
                }
            }
        }
        return length
    }

    private mutating func buildHillStraight(_ xo: Int, _ maxLength: Int) -> Int {
        let length = min(rng.nextInt(10) + 10, maxLength)
        let floor = height - 1 - rng.nextInt(4)
        for x in xo..<min(width, xo + length) {
            for y in floor..<height { set(x, y, Self.ground) }
        }
        addEnemyLine(xo + 1, xo + length - 1, floor - 1)
        var h = floor
        var occupied = [Bool](repeating: false, count: max(1, length))
        var keepGoing = true
        while keepGoing {
            h -= 2 + rng.nextInt(3)
            if h <= 0 { break }
            let l = rng.nextInt(5) + 3
            let span = max(1, length - l - 2)
            let xx = rng.nextInt(span) + xo + 1
            let indices = [xx - xo, xx - xo + l, xx - xo - 1, xx - xo + l + 1]
            if indices.contains(where: { $0 < 0 || $0 >= occupied.count || occupied[$0] }) {
                keepGoing = false
                continue
            }
            occupied[xx - xo] = true
            occupied[xx - xo + l] = true
            addEnemyLine(xx, xx + l, h - 1)
            if rng.nextInt(4) == 0 {
                decorate(xx - 1, xx + l + 1, h)
                keepGoing = false
            }
            for x in xx..<min(width, xx + l) {
                for y in h..<floor where y >= 0 {
                    let xxPic = x == xx ? 4 : (x == xx + l - 1 ? 6 : 5)
                    let yyPic = y == h ? 8 : 9
                    if get(x, y) == 0 { set(x, y, UInt8(xxPic + yyPic * 16)) }
                    else if get(x, y) == 132 { set(x, y, 180) }
                    else if get(x, y) == 134 { set(x, y, 182) }
                }
            }
        }
        return length
    }

    private mutating func addEnemyLine(_ x0: Int, _ x1: Int, _ y: Int) {
        guard y >= 0 else { return }
        for x in x0..<min(x1, width) where x >= 0 {
            if rng.nextInt(35) < difficulty + 1 {
                var enemyType = rng.nextInt(4)
                if difficulty < 1 { enemyType = 2 }
                else if difficulty < 3 { enemyType = rng.nextInt(3) }
                let winged = rng.nextInt(35) < difficulty
                enemySpawns.append(.init(x: x, y: y, type: enemyType, winged: winged))
            }
        }
    }

    private mutating func buildTubes(_ xo: Int, _ maxLength: Int) -> Int {
        let length = min(rng.nextInt(10) + 5, maxLength)
        let floor = height - 1 - rng.nextInt(4)
        var tubeX = xo + 1 + rng.nextInt(4)
        var tubeHeight = floor - rng.nextInt(2) - 2
        for x in xo..<min(width, xo + length) {
            if x > tubeX + 1 {
                tubeX += 3 + rng.nextInt(4)
                tubeHeight = floor - rng.nextInt(2) - 2
            }
            if tubeX >= xo + length - 2 { tubeX += 10 }
            if x == tubeX && rng.nextInt(11) < difficulty + 1 {
                enemySpawns.append(.init(x: x, y: tubeHeight, type: 4, winged: false))
            }
            for y in 0..<height {
                if y >= floor { set(x, y, Self.ground) }
                else if (x == tubeX || x == tubeX + 1) && y >= tubeHeight {
                    let picX = 10 + x - tubeX
                    set(x, y, UInt8(picX + (y == tubeHeight ? 0 : 16)))
                }
            }
        }
        return length
    }

    private mutating func buildStraight(_ xo: Int, _ maxLength: Int, safe: Bool) -> Int {
        var length = rng.nextInt(10) + 2
        if safe { length = 10 + rng.nextInt(5) }
        length = min(length, maxLength)
        let floor = height - 1 - rng.nextInt(4)
        for x in xo..<min(width, xo + length) {
            for y in floor..<height { set(x, y, Self.ground) }
        }
        if !safe && length > 5 { decorate(xo, xo + length, floor) }
        return length
    }

    private mutating func decorate(_ x0: Int, _ x1: Int, _ floor: Int) {
        guard floor >= 1 else { return }
        addEnemyLine(x0 + 1, x1 - 1, floor - 1)
        var s = rng.nextInt(4)
        var e = rng.nextInt(4)
        if floor - 2 > 0 && (x1 - 1 - e) - (x0 + 1 + s) > 1 {
            for x in (x0 + 1 + s)..<(x1 - 1 - e) { set(x, floor - 2, 34) }
        }
        s = rng.nextInt(4)
        e = rng.nextInt(4)
        if floor - 4 > 0 && (x1 - 1 - e) - (x0 + 1 + s) > 2 {
            for x in (x0 + 1 + s)..<(x1 - 1 - e) {
                if x != x0 + 1 && x != x1 - 2 && rng.nextInt(3) == 0 {
                    set(x, floor - 4, UInt8(rng.nextInt(4) == 0 ? 22 : 21))
                } else if rng.nextInt(4) == 0 {
                    set(x, floor - 4, UInt8(rng.nextInt(4) == 0 ? 18 : 17))
                } else { set(x, floor - 4, 16) }
            }
        }
    }

    private mutating func fixWalls() {
        var solid = Array(repeating: Array(repeating: false, count: height + 1), count: width + 1)
        for x in 0...width {
            for y in 0...height {
                var count = 0
                for xx in (x - 1)..<x + 1 {
                    for yy in (y - 1)..<y + 1 where getCapped(xx, yy) == Self.ground { count += 1 }
                }
                solid[x][y] = count == 4
            }
        }
        blockify(solid)
    }

    /// Direct translation of LevelGenerator.blockify() from the Java source.
    private mutating func blockify(_ blocks: [[Bool]]) {
        let offset = type == .castle ? 8 : (type == .underground ? 12 : 0)
        for x in 0...width {
            for y in 0...height {
                let a = blocks[x][y]                 // b[0][0]
                let b = blocks[min(x + 1, width)][y]             // b[1][0]
                let c = blocks[x][min(y + 1, height)]             // b[0][1]
                let d = blocks[min(x + 1, width)][min(y + 1, height)] // b[1][1]
                var tileID: UInt8?

                if a == b && c == d {
                    if a == c {
                        if a { tileID = UInt8(145 + offset) }
                        // Empty area: preserve the existing decoration.
                    } else if a {
                        tileID = UInt8(161 + offset)
                    } else {
                        tileID = UInt8(129 + offset)
                    }
                } else if a == c && b == d {
                    tileID = UInt8((a ? 146 : 144) + offset)
                } else if a == d && c == b {
                    tileID = UInt8(145 + offset)
                } else if a == b {
                    if a {
                        tileID = UInt8((c ? 163 : 179) + offset)
                    } else {
                        tileID = UInt8((c ? 130 : 128) + offset)
                    }
                } else if c == d {
                    if c {
                        tileID = UInt8((a ? 147 : 131) + offset)
                    } else {
                        tileID = UInt8((a ? 162 : 160) + offset)
                    }
                } else {
                    tileID = UInt8(16 + offset)
                }
                if let tileID { set(x, y, tileID) }
            }
        }
    }

    private func get(_ x: Int, _ y: Int) -> UInt8 {
        guard x >= 0, x < width, y >= 0, y < height else { return 0 }
        return map[x][y]
    }
    private func getCapped(_ x: Int, _ y: Int) -> UInt8 {
        map[min(max(x, 0), width - 1)][min(max(y, 0), height - 1)]
    }
    private mutating func set(_ x: Int, _ y: Int, _ value: UInt8) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        map[x][y] = value
    }
}

/// java.util.Random compatibility, including nextInt(bound)'s rejection path.
private struct JavaRandom {
    private var seed: UInt64
    private let multiplier: UInt64 = 0x5DEECE66D
    private let addend: UInt64 = 0xB
    private let mask: UInt64 = (1 << 48) - 1

    init(seed: UInt64) { self.seed = (seed ^ 0x5DEECE66D) & ((1 << 48) - 1) }

    private mutating func next(_ bits: Int) -> Int {
        seed = (seed &* multiplier &+ addend) & mask
        return Int(seed >> (48 - bits))
    }

    mutating func nextInt(_ bound: Int) -> Int {
        guard bound > 0 else { return 0 }
        if (bound & -bound) == bound {
            return Int((UInt64(bound) &* UInt64(next(31))) >> 31)
        }
        while true {
            let bits = next(31)
            let value = bits % bound
            // Java performs this overflow check as a signed 32-bit Int.
            let overflow = Int32(truncatingIfNeeded: bits - value + (bound - 1))
            if overflow >= 0 { return value }
        }
    }
}
