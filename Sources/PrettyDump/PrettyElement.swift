import Foundation

/// Элемент, содержащий объекты, которые могут быть представлен в красивом виде
public indirect enum PrettyElement: Sendable, Hashable {
    case bool(Bool)
    case double(Double)
    case int(Int)
    case uInt(UInt)
    case string(String)
    case null
    case collection([PrettyElement])
    case dictionary([PrettyElement: PrettyElement])
    case complex(PrettyElement, name: String)
}

extension PrettyElement {
    public func less(_ rhs: PrettyElement) -> Bool {
        switch (self, rhs) {
        case let (.bool(lhs), .bool(rhs)):
            !lhs && rhs
        case let (.double(lhs), .double(rhs)):
            lhs < rhs
        case let (.int(lhs), .int(rhs)):
            lhs < rhs
        case let (.uInt(lhs), .uInt(rhs)):
            lhs < rhs
        case let (.string(lhs), .string(rhs)):
            lhs < rhs
        case let (.complex(lhs, name: _), .complex(rhs, name: _)):
            lhs.less(rhs)
        case (_, _):
            false
        }
    }
}
