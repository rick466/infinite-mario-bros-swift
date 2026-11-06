import SpriteKit
import UIKit

enum SpriteSheet {
    static func texture(named name: String, cellSize: CGSize, column: Int, row: Int) -> SKTexture? {
        let fileURL = Bundle.module.url(forResource: name, withExtension: nil)
            ?? Bundle.module.url(forResource: name, withExtension: "png")

        guard let fileURL,
              let image = UIImage(contentsOfFile: fileURL.path),
              let cgImage = image.cgImage else {
            return nil
        }

        let pixelWidth = Int(cellSize.width * image.scale)
        let pixelHeight = Int(cellSize.height * image.scale)
        let x = column * pixelWidth
        let y = row * pixelHeight

        guard x + pixelWidth <= cgImage.width,
              y + pixelHeight <= cgImage.height,
              let cropped = cgImage.cropping(
                to: CGRect(x: x, y: y, width: pixelWidth, height: pixelHeight)
              ) else {
            return nil
        }

        return SKTexture(cgImage: cropped)
    }
}
