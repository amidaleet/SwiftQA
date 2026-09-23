import Foundation

extension Bool: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .bool(self)
    }
}

extension String: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .string(self)
    }
}

extension Double: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .double(self)
    }
}

extension Int: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .int(self)
    }
}

extension UInt: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .uInt(self)
    }
}

extension NSNull: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .null
    }
}

extension Array: PrettyConvertible where Element: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .collection(map(\.prettyElement))
    }
}

extension Set: PrettyConvertible where Element: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .collection(
            self
                .map(\.prettyElement)
                .sorted { $0.less($1) }
        )
    }
}

extension Dictionary: PrettyConvertible where Key: PrettyConvertible, Value: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .dictionary(
            self
                .mapKeys(\.prettyElement)
                .mapValues(\.prettyElement)
        )
    }
}

extension Optional: PrettyConvertible where Wrapped: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        switch self {
        case .none: .null
        case let .some(wrapped): wrapped.prettyElement
        }
    }
}
