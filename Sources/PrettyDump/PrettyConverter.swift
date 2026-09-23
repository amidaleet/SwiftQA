import Foundation

enum PrettyConverter {
    static func convert(_ value: Any) -> PrettyElement {
        if type(of: value) == AnyHashable.self, let hashable = value as? AnyHashable {
            // Нельзя просто так сравнивать с AnyHashable - компилятор неявно сконвертит в него
            return convert(hashable.base)
        } else if let result = value as? PrettyConvertible {
            return result.prettyElement
        } else if let element = convertWellKnown(value) {
            return element
        }

        let mirror = Mirror(reflecting: value)

        if !mirror.children.isEmpty {
            return convertInhabited(value, mirror: mirror)
        }

        if case .enum = mirror.displayStyle, let name = self
            .enumCaseName(value)
            .flatMap(String.init(validatingCString:)) {
            return .string(name)
        }

        let name = String(describing: value)
        return .string(name)
    }

    private static func convertWellKnown(_ value: Any) -> PrettyElement? {
        switch value {
        case let value as LocalizedError:
            // Здесь обрабатываем только LocalizedError, считая что они предоставляют более приоритетное описание
            // по сравнению с `Pretty.convert()`
            .string(value.errorDescription ?? value.localizedDescription)
        default:
            nil
        }
    }

    private static func convertInhabited(_ value: Any, mirror: Mirror) -> PrettyElement {
        switch mirror.displayStyle {
        case .enum: // Ассоциированные enum (всегда с одним child)
            if let child = mirror.children.first, let label = child.label {
                let newValue = convert(child.value)
                return .dictionary([.string(label): newValue])
            }
        case .optional: // Опционал (имеет или одного child или ни одного - null)
            if let child = mirror.children.first {
                return convert(child.value)
            }

            return .null
        case .dictionary:
            if let dictionary = value as? [AnyHashable: Any] {
                var result = [PrettyElement: PrettyElement]()

                for (key, value) in dictionary {
                    let newKey = convert(key)
                    let newValue = convert(value)
                    result[newKey] = newValue
                }

                return .dictionary(result)
            }
        case .class:
            // Не обрабатываем классы. Считаем что если нужно распечатать класс - переопределим его `PrettyConvertible`
            let string = String(describing: type(of: value))
            return .string(string)
        default:
            break
        }

        return convertChildren(mirror: mirror)
    }

    private static func convertChildren(mirror: Mirror) -> PrettyElement {
        var labeledElements = [PrettyElement: PrettyElement]()
        var unlabeledElements = [PrettyElement]()

        for child in mirror.children {
            let newValue = convert(child.value)

            if let label = child.label {
                labeledElements[.string(label)] = newValue
            } else {
                unlabeledElements.append(newValue)
            }
        }

        if !unlabeledElements.isEmpty {
            unlabeledElements += labeledElements.values
            return .collection(unlabeledElements)
        } else {
            return .dictionary(labeledElements)
        }
    }

    @_silgen_name("swift_EnumCaseName")
    private static func enumCaseName<T>(_ value: T) -> UnsafePointer<CChar>?
}
