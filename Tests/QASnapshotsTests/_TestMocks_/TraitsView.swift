import UIKit

/// Печатает трейты, с которыми его разложил холст
final class TraitsView: UIView {
    private let label = UILabel()

    private(set) var renderedTraits: UITraitCollection?

    init() {
        super.init(frame: .zero)
        backgroundColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .black
        label.font = .systemFont(ofSize: 24)
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        renderedTraits = traitCollection
        label.text = traitCollection.snapshotDescription
        label.frame = bounds
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        size
    }
}

extension UITraitCollection {
    fileprivate var snapshotDescription: String {
        """
        UIKit
        horizontal: \(horizontalSizeClass.snapshotDescription)
        vertical: \(verticalSizeClass.snapshotDescription)
        idiom: \(userInterfaceIdiom.snapshotDescription)
        """
    }
}

extension UIUserInterfaceIdiom {
    fileprivate var snapshotDescription: String {
        switch self {
        case .pad: "pad"
        case .phone: "phone"
        default: "\(rawValue)"
        }
    }
}
