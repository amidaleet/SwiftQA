import Foundation

public enum Pretty {
    /// Преобразовать это значение в отформатированный текст
    public static func string(_ value: Any?) -> String {
        let result = convert(value)
        return PrettyFormatter.string(result)
    }

    /// Преобразовать это значение в значение, пригодное для преобразования в _JSON_
    public static func json(_ value: Any?) -> any JSON {
        let result = convert(value)
        return PrettyFormatter.json(result)
    }

    /// Преобразовать это значение в "простое" (одно из базовых типов), которое поддерживает преобразование в JSON,
    /// либо другой простой вывод в текстовый формат
    public static func convert(_ value: Any?) -> PrettyElement {
        guard let value else {
            return .null
        }

        return PrettyConverter.convert(value)
    }
}
