import Foundation

/// Протокол для преобразования ошибок в ``NSError`` с дополнительными данными.
public protocol PrettyError: Error {
    /// Общий домен, классифицирующий этот тип ошибки. Все остальные параметры должны
    /// быть уникальны в этом домене
    static var errorDomain: String { get }

    /// Имя ошибки, уникальное в пределах домена
    var errorName: String { get }

    /// Дополнительный внутренний числовой код ошибки, уникальный в пределах домена, если существует
    var errorCode: Int { get }

    /// Дополнительный поля об ошибке. Должны быть сериализуемы в JSON
    var errorUserInfo: [String: any JSON] { get }
}

extension PrettyError {
    @inlinable
    public static var errorDomain: String {
        String(describing: self).camelCaseToHyphenCase()
    }

    @inlinable
    public var errorCode: Int {
        .noPrettyErrorCode
    }

    @inlinable
    public var errorName: String {
        Self.errorDomain
    }

    @inlinable
    public var errorDomain: String {
        Self.errorDomain
    }

    @inlinable
    public var errorUserInfo: [String: any JSON] {
        [:]
    }
}

extension PrettyError where Self: Identifiable {
    @inlinable
    public var errorName: String {
        String(describing: id).camelCaseToHyphenCase()
    }
}

extension PrettyError where Self: Identifiable, ID: CaseIterable, ID.AllCases.Index == Int {
    @inlinable
    public var errorCode: Int {
        if let index = ID.allCases.firstIndex(of: id) {
            return index
        }

        return 0
    }
}

extension Int {
    /// Код ошибки, в тех случаях, когда он не предполагается (например - ошибка всегда одного типа)
    /// - Note: Из-за конверсии в `NSError`, архитектурно было решено использовать значение вместо `null`
    public static let noPrettyErrorCode = 1_024
}

extension Error {
    public var prettyNSError: NSError {
        var domain: String
        let code: Int
        var userInfo: [String: Any]

        if let error = self as? PrettyError {
            domain = error.errorDomain
            code = error.errorCode
            userInfo = error.errorUserInfo
            userInfo["ns.name"] = error.errorName
        } else {
            let error = self as NSError
            domain = error.domain
            code = error.code
            userInfo = error.userInfo
        }

        if code != .noPrettyErrorCode {
            userInfo["ns.code"] = code
        }

        // Делаем имя домена более красивым

        switch domain {
        case NSURLErrorDomain:
            domain = "url-error"
        case NSCocoaErrorDomain:
            domain = "cocoa-error"
        default:
            break
        }

        // Метричные системы ограничивают имя параметра. Имена из Foundation не проходят

        userInfo["ns.domain"] = domain

        if let value = userInfo.removeValue(forKey: NSURLErrorFailingURLErrorKey) {
            userInfo["url"] = value
        }

        if let value = userInfo.removeValue(forKey: NSURLErrorFailingURLStringErrorKey) {
            userInfo["urlString"] = value
        }

        if let value = userInfo.removeValue(forKey: NSUnderlyingErrorKey) {
            userInfo["underlyingError"] = value
        }

        if let value = userInfo.removeValue(forKey: "_kCFStreamErrorCodeKey") {
            userInfo["cf.streamCode"] = value
        }

        if let value = userInfo.removeValue(forKey: "_kCFStreamErrorDomainKey") {
            userInfo["cf.streamDomain"] = value
        }

        // Следующие поля бесполезны, вырезаем их

        userInfo["_NSURLErrorFailingURLSessionTaskErrorKey"] = nil
        userInfo["_NSURLErrorRelatedURLSessionTaskErrorKey"] = nil

        return NSError(domain: domain, code: code, userInfo: userInfo)
    }

    public var prettyErrorDomain: String {
        if let error = self as? PrettyError {
            error.errorDomain
        } else {
            nsDomain
        }
    }

    public var prettyErrorCode: Int {
        if let error = self as? PrettyError {
            error.errorCode
        } else {
            nsCode
        }
    }
}

extension Pretty {
    @inlinable
    public static func errorName<T>(_ errorType: T) -> String where T: RawRepresentable {
        String(describing: errorType)
    }

    /// Объединение информации из существующего словаря и ошибки ``PrettyError``
    public static func errorUserInfo(_ error: Error? = nil, from userInfo: [String: Any] ...) -> [String: Any] {
        var result: [String: Any] = [:]

        if let error {
            let nsError = error.prettyNSError

            let newUserInfo = nsError.userInfo.mapKeys { nsError.domain + "." + $0 }

            result.merge(newUserInfo) { $1 }
        }

        for userInfo in userInfo {
            result.merge(userInfo) { _, new in new }
        }

        return result
    }
}
