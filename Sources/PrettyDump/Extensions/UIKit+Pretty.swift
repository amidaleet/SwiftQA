#if canImport(UIKit)

import UIKit

extension UIInterfaceOrientation: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        let value: String

        switch self {
        case .unknown:
            value = "unknown"
        case .portrait:
            value = "portrait"
        case .portraitUpsideDown:
            value = "portraitUpsideDown"
        case .landscapeLeft:
            value = "landscapeLeft"
        case .landscapeRight:
            value = "landscapeRight"
        @unknown default:
            value = "unknown"
        }

        return .string(value)
    }
}

#endif
