import Foundation

/// Объект, предоставляющий сохранение своей структуры, для последующего  _красивого_ отображения
/// - Note: Конформ и имплементация требуется только для тех случаев, когда стандартный ``Pretty/convert(_:)``
/// дает нежелательный результат (например, для сложных классов, в которых нежелательно показывать внутреннюю
/// часть).
public protocol PrettyConvertible {
    /// Создание элемента, который может использоваться для сериализации и дальнейшего _красивого_ отображения
    var prettyElement: PrettyElement { get }
}

/// Представление элемента, который НЕ может быть красиво представлен
public protocol PrettyUnconvertible: PrettyConvertible {}

/// Хелпер для автоматической генерации ``PrettyConvertible/prettyElement`` для ``RawRepresentable``
public protocol PrettyRawConvertible: PrettyConvertible {}

extension PrettyUnconvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        let string = String(describing: type(of: self))
        return .string(string)
    }
}

extension PrettyRawConvertible where Self: RawRepresentable, RawValue: PrettyConvertible {
    @inlinable
    public var prettyElement: PrettyElement {
        rawValue.prettyElement
    }
}
