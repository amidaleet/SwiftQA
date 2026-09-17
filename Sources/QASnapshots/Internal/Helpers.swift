import UIKit

extension Optional {
    func get(elseThrow error: @autoclosure () -> Error) throws -> Wrapped {
        guard let value = self else { throw error() }
        return value
    }
}

extension SnapshotDevice {
    @discardableResult
    func configure(_ block: (inout Self) throws -> Void) rethrows -> Self {
        var obj = self
        try block(&obj)
        return obj
    }
}

extension UIEdgeInsets {
    init(top: CGFloat = 0, bottom: CGFloat = 0) {
        self.init(top: top, left: 0, bottom: bottom, right: 0)
    }

    init(horizontal: CGFloat = 0, vertical: CGFloat = 0) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    static func - (lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: lhs.top - rhs.top,
            left: lhs.left - rhs.left,
            bottom: lhs.bottom - rhs.bottom,
            right: lhs.right - rhs.right
        )
    }
}

extension UIViewController {
    var originalSafeInsets: UIEdgeInsets {
        view.safeAreaInsets - additionalSafeAreaInsets
    }

    func add(_ child: UIViewController, in subview: UIView? = nil) {
        let container: UIView = subview ?? view
        addChild(child)
        container.addSubview(child.view)
        child.didMove(toParent: self)
    }

    func remove() {
        guard parent != nil else { return }

        willMove(toParent: nil)
        removeFromParent()
        viewIfLoaded?.removeFromSuperview()
        didMove(toParent: nil)
    }
}

extension CGRect {
    var center: CGPoint {
        get { CGPoint(x: midX, y: midY) }
        set {
            origin.x = newValue.x - size.width / 2
            origin.y = newValue.y - size.height / 2
        }
    }

    init(origin: CGPoint, width: CGFloat, height: CGFloat) {
        self.init(x: origin.x, y: origin.y, width: width, height: height)
    }

    init(center: CGPoint, size: CGSize) {
        let x = center.x - size.width * 0.5
        let y = center.y - size.height * 0.5
        self.init(origin: CGPoint(x: x, y: y), size: size)
    }
}

extension CGSize {
    init(square: CGFloat) {
        self.init(width: square, height: square)
    }
}

extension Bundle {
    func tryChild(_ name: String) -> Bundle? {
        path(forResource: name, ofType: "bundle").flatMap(Bundle.init)
    }
}
