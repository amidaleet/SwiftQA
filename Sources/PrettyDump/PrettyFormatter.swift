import Foundation

enum PrettyFormatter {
    static func json(_ value: PrettyElement) -> any JSON {
        switch value {
        case let .bool(value): value
        case let .double(value): value
        case let .int(value): value
        case let .uInt(value): value
        case let .string(value): value
        case .null: NSNull()
        case let .collection(value):
            value.map { json($0) }
        case let .dictionary(value):
            value
                .mapKeys {
                    String(describing: json($0))
                }
                .mapValues {
                    json($0)
                }
        case let .complex(value, _):
            json(value)
        }
    }

    static func string(_ value: PrettyElement) -> String {
        var string = ""

        dump(value, to: &string, tab: 0, inlined: true)

        return string
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func dump(
        _ element: PrettyElement,
        to stream: inout String,
        tab: Int,
        inlined: Bool
    ) {
        let prefix = String(repeating: "  ", count: tab)
        let offset = inlined ? "" : String(repeating: "  ", count: tab)

        switch element {
        case let .bool(value):
            stream += offset + String(describing: value)
        case let .double(value):
            stream += offset + String(describing: value)
        case let .int(value):
            stream += offset + String(describing: value)
        case let .uInt(value):
            stream += offset + String(describing: value)
        case let .string(value):
            stream += offset + value
        case .null:
            stream += offset + "null"
        case let .collection(value):
            if value.isEmpty {
                stream += "[]"
            } else {
                stream += offset + "[\r"

                for element in value {
                    dump(
                        element,
                        to: &stream,
                        tab: tab + 1,
                        inlined: false
                    )
                    stream += ", \r"
                }

                stream += prefix + "]"
            }
        case let .dictionary(value):
            if value.isEmpty {
                stream += "[:]"
            } else {
                stream += offset + "[\r"

                for (key, value) in value.sorted(by: { $0.key.less($1.key) }) {
                    dump(
                        key,
                        to: &stream,
                        tab: tab + 1,
                        inlined: false
                    )

                    stream += ": "

                    dump(
                        value,
                        to: &stream,
                        tab: tab + 1,
                        inlined: true
                    )

                    stream += ", \r"
                }

                stream += prefix + "]"
            }
        case let .complex(value, name):
            dump(value, to: &stream, tab: tab, inlined: inlined)
            stream += " [\(name)]"
        }
    }
}
