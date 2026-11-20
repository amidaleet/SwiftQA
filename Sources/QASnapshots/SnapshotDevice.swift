import UIKit

/// "Холст" для съемки снепшота, описывает параметры целевого устройства.
/// Определяет size, scale, safeArea и включен ли crop по sut.frame
public struct SnapshotDevice: Sendable {
    private var safeArea: SafeAreaInsets

    public let scale: CGFloat
    /// Orientation based size
    public private(set) var size: CGSize

    public var orientation: Orientation {
        didSet {
            if orientation != oldValue {
                size = size.flipped()
            }
        }
    }

    /// Orientation based safe area insets
    public var insets: UIEdgeInsets {
        safeArea.insets(orientation: orientation)
    }

    /// Apply specified safe area (or set it to .zero)
    public var isSafeAreaOn: Bool {
        get { safeArea.isOn }
        set { safeArea.isOn = newValue }
    }

    /// Crop snapshot to sut view frame (use full screen size instead if turned off)
    public var isCropOn: Bool

    /// Трейты, которые видит снимаемый контент: size class и idiom
    ///
    /// По умолчанию ``Traits/simulator``: трейты не переопределяются и берутся от симулятора
    public var traits: Traits

    public init(
        portraitWidth: CGFloat,
        portraitHeight: CGFloat,
        scale: CGFloat,
        portraitSafeArea: UIEdgeInsets,
        landscapeSafeArea: UIEdgeInsets,
        orientation: Orientation,
        isCropOn: Bool = false,
        traits: Traits = .simulator
    ) {
        let size = CGSize(width: portraitWidth, height: portraitHeight)
        switch orientation {
        case .portrait:
            self.size = size
        case .landscape:
            self.size = size.flipped()
        }

        self.scale = scale
        self.safeArea = SafeAreaInsets(
            portrait: portraitSafeArea,
            landscape: landscapeSafeArea,
            isOn: portraitSafeArea != .zero || landscapeSafeArea != .zero
        )
        self.orientation = orientation
        self.isCropOn = isCropOn
        self.traits = traits
    }

    mutating func flip() {
        switch orientation {
        case .portrait:
            orientation = .landscape
        case .landscape:
            orientation = .portrait
        }
    }

    /// Половина кадра двойной ширины: тот же девайс, ширина вдвое меньше.
    /// Её передают теме, когда половины кадра собирают вручную.
    public var halfWidth: SnapshotDevice {
        var half = self
        half.size.width /= 2
        return half
    }

    /// Часть имени эталона, которая отличает девайсы группы
    var referenceSizeName: String {
        "\(Int(size.width))x\(Int(size.height))@\(Int(scale))x"
    }

    func referenceURL(testName: String, suffix: String, testFile: StaticString) -> URL {
        let name = testName
            .replacingOccurrences(of: "test_", with: "")
            .replacingOccurrences(of: "()", with: "")
            .appending(suffix)

        return URL(
            fileURLWithPath: "\(testFile)",
            isDirectory: true
        )
        .deletingLastPathComponent()
        .appendingPathComponent("_Snapshots_", isDirectory: true)
        .appendingPathComponent("\(name)_\(referenceSizeName).png")
    }
}

extension SnapshotDevice {
    public enum Orientation: String, Sendable {
        case landscape
        case portrait
    }

    struct SafeAreaInsets: Sendable {
        let portrait: UIEdgeInsets
        let landscape: UIEdgeInsets
        var isOn: Bool

        init(
            portrait: UIEdgeInsets,
            landscape: UIEdgeInsets,
            isOn: Bool
        ) {
            self.portrait = portrait
            self.landscape = landscape
            self.isOn = isOn
        }

        func insets(orientation: Orientation) -> UIEdgeInsets {
            guard isOn else { return .zero }

            switch orientation {
            case .portrait: return portrait
            case .landscape: return landscape
            }
        }
    }
}

extension SnapshotDevice {
    /// Переопределение трейтов холста. `nil` в поле — значение берётся от симулятора
    public struct Traits: Sendable, Equatable {
        public var horizontalSizeClass: UIUserInterfaceSizeClass?
        public var verticalSizeClass: UIUserInterfaceSizeClass?
        public var userInterfaceIdiom: UIUserInterfaceIdiom?

        var isEmpty: Bool {
            horizontalSizeClass == nil && verticalSizeClass == nil && userInterfaceIdiom == nil
        }

        public init(
            horizontalSizeClass: UIUserInterfaceSizeClass? = nil,
            verticalSizeClass: UIUserInterfaceSizeClass? = nil,
            userInterfaceIdiom: UIUserInterfaceIdiom? = nil
        ) {
            self.horizontalSizeClass = horizontalSizeClass
            self.verticalSizeClass = verticalSizeClass
            self.userInterfaceIdiom = userInterfaceIdiom
        }

        /// Без переопределения: трейты симулятора iPhone
        public static let simulator = Traits()

        /// iPad на весь экран в любой ориентации
        public static let iPad = Traits(
            horizontalSizeClass: .regular,
            verticalSizeClass: .regular,
            userInterfaceIdiom: .pad
        )

        /// Узкая колонка iPad: Slide Over и Split View 1/3, на iPad mini — ещё и 1/2
        public static let iPadCompactColumn = Traits(
            horizontalSizeClass: .compact,
            verticalSizeClass: .regular,
            userInterfaceIdiom: .pad
        )
    }
}

extension SnapshotDevice {
    var specText: String {
        let insets = self.insets
        return """
        	Size: \(size)
        	Insets: [
        		top: \(insets.top)
        		left: \(insets.left)
        		right: \(insets.right)
        		bottom: \(insets.bottom)
        	]
        	Orientation: \(orientation)
        """
    }

    var attachmentDescription: String {
        """
        Orientation: \(orientation.rawValue) \
        Size: w: \(size.width) h: \(size.height)
        """
    }
}

extension CGSize {
    fileprivate func flipped() -> CGSize {
        CGSize(width: height, height: width)
    }
}
