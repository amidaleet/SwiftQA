import Foundation

extension String {
    /// Преобразовать строку с camel case в строку с дефисами вместо больших буков, например `myEnumCase` -> `my-enum-case`
    /// Кроме того, строки с серией заглавных букв также отделяются дефисом, например - `NSError` -> `ns-error`
    @usableFromInline
    internal func camelCaseToHyphenCase() -> String {
        var uppercaseCount = 0
        var result = ""
        let characters = Array(self)

        for offset in characters.indices {
            let character = characters[offset]

            if offset > 0 {
                let isNextLowercase = offset < characters.endIndex - 1 && !characters[offset + 1].isUppercase
                let isSeriesToLowerMove = uppercaseCount > 0 && character.isUppercase && isNextLowercase
                let isLowerToUpperMove = uppercaseCount == 0 && character.isUppercase

                if isSeriesToLowerMove || isLowerToUpperMove {
                    result += "-"
                }
            }

            if character.isUppercase {
                uppercaseCount += 1
            } else {
                uppercaseCount = 0
            }

            result += character.lowercased()
        }

        return result
    }
}

extension Dictionary {
    /// Возвращает новый словарь с теми же значениями что и ранее но ключами,
    /// трансформированными `transform`
    ///
    /// - Precondition: Трансформированная последовательность ключей не
    /// должна иметь дубликатов
    ///
    /// - Complexity: O(*n*), где *n* длина словаря
    @usableFromInline
    internal func mapKeys<T>(_ transform: (Key) throws -> T) rethrows -> [T: Value] where T: Hashable {
        try [T: Value](uniqueKeysWithValues: map { (try transform($0.key), $0.value) })
    }
}

extension Error {
    internal var nsCode: Int {
        (self as NSError).code
    }

    internal var nsDomain: String {
        (self as NSError).domain
    }
}
