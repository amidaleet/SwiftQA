import UIKit

struct Snapshot: Sendable {
    /// Исходный записанный с экрана UIImage
    ///
    /// scale > 1 – размер одного point == scale * scale (в pixels)
    let original: UIImage

    private var scaled: UIImage?

    init(original: UIImage) {
        self.original = original
    }

    /// Картинка отрисованная в points размере со scale == 1, point == pixel
    ///
    /// Ускоряет алгоритмы рассчета diff
    mutating func scaledForComparison() -> UIImage {
        if let scaled {
            return scaled
        }
        if original.scale == 1 {
            self.scaled = original
            return original
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let scaled = UIGraphicsImageRenderer(size: original.size, format: format)
            .image { _ in original.draw(at: .zero) }
        self.scaled = scaled
        return scaled
    }
}
