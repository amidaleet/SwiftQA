import Foundation

extension Data: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        // swiftlint:disable:next non_optional_string_data_conversion
        guard let string = String(data: self, encoding: .utf8) else {
            let string = "<" + String(describing: count) + ">"
            return .string(string)
        }

        return .string(string)
    }
}

extension Date: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        let string = String(describing: self)
        return .string(string)
    }
}

extension URL: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .string(absoluteString)
    }
}

extension Bundle: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        .string(bundlePath)
    }
}

extension URLRequest: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        let fields = [
            "method": httpMethod,
            "url": url,
            "headers": allHTTPHeaderFields,
            "body": httpBody,
        ] as [String: Any?]

        return Pretty.convert(fields.compactMapValues { $0 })
    }
}
