import Foundation

struct GameLevel {
    let width: Int
    let height: Int
    var tiles: [[Bool]]
    let questionBlockPositions: [SIMD2<Int>]
    let coinPositions: [SIMD2<Int>]

    init(width: Int = 220, height: Int = 15) {
        self.width = width
        self.height = height

        var t = Array(repeating: Array(repeating: false, count: height), count: width)

        for x in 0..<width {
            let floor = 12 - ((x / 31) % 3)
            for y in floor..<height {
                t[x][y] = true
            }
        }

        for x in 18..<24 { t[x][9] = true }
        for x in 28..<34 { t[x][7] = true }
        for x in 43..<49 { t[x][9] = true }
        for x in 56..<61 { t[x][8] = true }
        for x in 70..<77 { t[x][6] = true }
        for x in 84..<90 { t[x][9] = true }
        for x in 101..<108 { t[x][7] = true }
        for x in 119..<125 { t[x][9] = true }
        for x in 136..<142 { t[x][6] = true }
        for x in 154..<161 { t[x][8] = true }
        for x in 175..<182 { t[x][9] = true }
        for x in 194..<201 { t[x][7] = true }

        for x in [37, 38, 39, 62, 63, 93, 94, 127, 128, 164, 165, 184, 185] {
            if x < width {
                for y in 10..<height {
                    t[x][y] = false
                }
            }
        }

        let blocks: [SIMD2<Int>] = [
            .init(21, 7), .init(31, 5), .init(46, 7),
            .init(58, 6), .init(73, 4), .init(87, 7),
            .init(104, 5), .init(121, 7), .init(138, 4),
            .init(157, 6), .init(178, 7), .init(197, 5)
        ]

        for p in blocks where p.x >= 0 && p.x < width && p.y >= 0 && p.y < height {
            t[p.x][p.y] = true
        }

        questionBlockPositions = blocks

        coinPositions = [
            .init(20, 8), .init(22, 8), .init(31, 6),
            .init(32, 6), .init(46, 8), .init(48, 8),
            .init(58, 7), .init(73, 5), .init(74, 5),
            .init(87, 8), .init(104, 6), .init(121, 8),
            .init(138, 5), .init(157, 7), .init(178, 8),
            .init(197, 6)
        ]

        tiles = t
    }

    func isSolid(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else {
            return y < 0 || x < 0 || x >= width
        }
        return tiles[x][y]
    }
}
