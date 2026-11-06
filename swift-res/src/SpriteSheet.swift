import SpriteKit
import UIKit

enum SpriteSheet {
    static func texture(named name: String, cellSize: CGSize, column: Int, row: Int) -> SKTexture? {
        guard let image = UIImage(named: name)?.cgImage else { return nil }

        let pixelWidth = Int(cellSize.width)
        let pixelHeight = Int(cellSize.height)
        let x = column * pixelWidth
        let y = row * pixelHeight

        guard let cropped = image.cropping(to: CGRect(x: x, y: y, width: pixelWidth, height: pixelHeight)) else {
            return nil
        }

        return SKTexture(cgImage: cropped)
    }
}
