import Foundation

extension DecodingError: PrettyConvertible, PrettyError {
    private enum UserInfoKey: String {
        case key
        case type
        case description
        case codingPath
    }

    public var errorCode: Int {
        switch self {
        case .typeMismatch: 0
        case .valueNotFound: 1
        case .keyNotFound: 2
        case .dataCorrupted: 3
        @unknown default: .noPrettyErrorCode
        }
    }

    public var errorName: String {
        switch self {
        case .typeMismatch: "Type mismatch"
        case .valueNotFound: "Value not found"
        case .keyNotFound: "Key not found"
        case .dataCorrupted: "Data corrupted"
        @unknown default: ""
        }
    }

    public var errorUserInfo: [String: any JSON] {
        var result = [UserInfoKey: any JSON]()

        switch self {
        case let .typeMismatch(_, context):
            addContext(context, to: &result)
        case let .valueNotFound(type, context):
            result[.type] = String(describing: type)
            addContext(context, to: &result)
        case let .keyNotFound(key, context):
            result[.key] = key.stringValue
            addContext(context, to: &result)
        case let .dataCorrupted(context):
            addContext(context, to: &result)
        @unknown default:
            break
        }

        return result.mapKeys(\.rawValue)
    }

    public var prettyElement: PrettyElement {
        .dictionary([
            .string("code"): .int(errorCode),
            .string("name"): .string(errorName),
            .string("userInfo"): Pretty.convert(errorUserInfo),
        ])
    }

    private func addContext(_ context: Context, to elements: inout [UserInfoKey: any JSON]) {
        elements[.description] = context.debugDescription

        elements[.codingPath] = context.codingPath
            .map {
                if let value = $0.intValue {
                    return "\(value)"
                }
                return $0.stringValue
            }
            .joined(separator: "/")
    }
}
