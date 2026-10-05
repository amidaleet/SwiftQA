import Foundation

/// Синтезирует `Equatable` обходом зеркала.
///
/// `==` идёт через вызов `areMirrorEqual()`
public protocol MirrorEquatable: Equatable {}

extension MirrorEquatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        areMirrorEqual(lhs, rhs)
    }
}

/// Маркерный протокол для предотвращения зеркального сравнения объектов в areMirrorEqual()
public protocol AlwaysEqualToSameMetatypeInMirror {
    func isSameMirrorMetatype(as other: any AlwaysEqualToSameMetatypeInMirror) -> Bool
}

extension AlwaysEqualToSameMetatypeInMirror {
    public func isSameMirrorMetatype(as other: any AlwaysEqualToSameMetatypeInMirror) -> Bool {
        other is Self
    }
}

// Оригинал идеи взят из пакета https://github.com/krzysztofzablocki/Difference версии 1.0.0 (код с большими изменениями)
// swiftlint:disable:next cyclomatic_complexity
public func areMirrorEqual<T>(
    _ expected: T,
    _ received: T
) -> Bool {
    let expectedMirror = Mirror(reflecting: expected)
    let receivedMirror = Mirror(reflecting: received)

    guard !expectedMirror.children.isEmpty, !receivedMirror.children.isEmpty else {
        return areEnumCasesEqual(
            expected,
            received,
            lhsMirror: expectedMirror,
            rhsMirror: receivedMirror
        ) ?? (expectedMirror.children.isEmpty && receivedMirror.children.isEmpty)
    }

    guard expectedMirror.children.count == receivedMirror.children.count else {
        return false
    }
    switch (expectedMirror.displayStyle, receivedMirror.displayStyle) {
    case (.dictionary?, .dictionary?):
        if let expectedDict = expected as? [AnyHashable: Any],
           let receivedDict = received as? [AnyHashable: Any] {
            let missingKeys = Set(expectedDict.keys).subtracting(receivedDict.keys)
            let extraKeys = Set(receivedDict.keys).subtracting(expectedDict.keys)

            guard missingKeys.isEmpty, extraKeys.isEmpty else {
                return false
            }
            let commonKeys = Set(receivedDict.keys).intersection(expectedDict.keys)

            for key in commonKeys {
                if !areMirrorEqual(expectedDict[key], receivedDict[key]) {
                    return false
                }
            }
            return true
        }
    case (.set?, .set?):
        if let expectedSet = expected as? Set<AnyHashable>,
           let receivedSet = received as? Set<AnyHashable> {
            if !expectedSet.subtracting(receivedSet).isEmpty || !receivedSet.subtracting(expectedSet).isEmpty {
                return false
            }
            return true
        }
    case (.enum?, .enum?) where expectedMirror.children.first?.label != receivedMirror.children.first?.label:
        return false
    default:
        break
    }

    let zipped = zip(expectedMirror.children, receivedMirror.children)
    for zippedValues in zipped {
        if let left = zippedValues.0.value as? AlwaysEqualToSameMetatypeInMirror,
           let right = zippedValues.1.value as? AlwaysEqualToSameMetatypeInMirror {
            if left.isSameMirrorMetatype(as: right) {
                continue
            } else {
                return false
            }
        }
        if zippedValues.0.value is UnsafeMutablePointer<os_unfair_lock>,
           zippedValues.1.value is UnsafeMutablePointer<os_unfair_lock> {
            continue
        }

        if let lhs = zippedValues.0.value as? AnyHashable,
           let rhs = zippedValues.1.value as? AnyHashable {
            if lhs != rhs {
                return false
            }
        } else {
            if !areMirrorEqual(zippedValues.0.value, zippedValues.1.value) {
                return false
            }
        }
    }
    return true
}

private func areEnumCasesEqual<T>(
    _ lhs: T,
    _ rhs: T,
    lhsMirror: Mirror,
    rhsMirror: Mirror
) -> Bool? {
    guard lhsMirror.displayStyle == .some(.enum),
          rhsMirror.displayStyle == .some(.enum)
    else { return nil }

    guard let expectedCaseName = enumCaseName(lhs),
          let receivedCaseName = enumCaseName(rhs)
    else {
        /// При передачи в MirrorEqutable символов, которые читаются как `__C.*`
        /// необходимо сравнивать дополнительно строки через CustomStringConvertible
        if let lhsString = lhs as? CustomStringConvertible,
           let rhsString = rhs as? CustomStringConvertible {
            return lhsString.description == rhsString.description
        }
        fatalError(
            "caseName fetching error for enum: \(lhsMirror.subjectType)"
        )
    }
    return expectedCaseName == receivedCaseName
}

private func enumCaseName<T>(_ value: T) -> String? {
    _getEnumCaseName(value).flatMap { String(validatingCString: $0) }
}

@_silgen_name("swift_EnumCaseName")
private func _getEnumCaseName<T>(_ value: T) -> UnsafePointer<CChar>?

extension String {
    fileprivate init<T>(dumping object: T) {
        self.init()
        dump(object, to: &self)
        self = withoutDumpArtifacts
    }

    // Removes the artifacts of using dumping initialiser to improve readability
    private var withoutDumpArtifacts: String {
        self.replacingOccurrences(of: "- ", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}
