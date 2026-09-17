import SwiftUI
import UIKit
import XCTest

public enum Snapshots {
    /// Ассерт на визуальное соответствие снимка (snapshot) тестируемого UIView (sut)
    /// ожидаемому изображению (reference)
    ///
    /// - Note: Универсальный метод. Позволяет сделать запись нового reference.
    /// Сценарий определяет `mode`
    public static func match(
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line,
        matcher: SnapshotMatcherKind = .default,
        mode: SnapshotMode = .verify,
        deviceGroup: SnapshotDeviceGroup = .phone,
        includeAccessibility: Bool = false,
        prepareSut: @MainActor @escaping (SnapshotDevice) throws -> SnapshotSut
    ) async {
        if case .record = mode {
            guard assertSimulatorIfNeeded(file: file, line: line) else { return }
        }

        var snapshotKinds: [SnapshotKind] = [.interface]
        if includeAccessibility {
            snapshotKinds.append(.accessibility)
        }

        var errors = await withTaskGroup(of: Error?.self, returning: [Error].self) { group in
            let sutChecker = SnapshotSutChecker()
            for screen in deviceGroup.devices {
                for snapshotKind in snapshotKinds {
                    group.addTask {
                        do {
                            let snapshot = try await Task { @MainActor in
                                let sut = try prepareSut(screen)
                                try sutChecker.check(sut)
                                return try SnapshotCanvas(
                                    sut: sut,
                                    screen: screen,
                                    snapshotKind: snapshotKind
                                )
                                .capture()
                                .get(elseThrow: SnapshotError.snapshotRecordFailed)
                            }.value
                            let files = try SnapshotFiles(
                                device: screen,
                                testName: testName,
                                suffix: snapshotKind.referenceFileSuffix,
                                testFile: file,
                                isComparisonFilesUseful: true
                            )
                            try await matcher.run(
                                snapshot: snapshot,
                                files: files,
                                mode: mode
                            )
                            return nil
                        } catch {
                            return error
                        }
                    }
                }
            }

            return await group.reduce(into: [Error]()) {
                if let error = $1 {
                    $0.append(error)
                }
            }
        }
        switch mode {
        case .verify:
            if !errors.isEmpty {
                assertSimulatorIfNeeded(file: file, line: line)
            }
        case .record:
            errors.append(SnapshotError.recordModeEnabled)
        }
        for error in errors {
            XCTFail(Pretty.string(error), file: file, line: line)
        }
    }

    /// Ассерт на получение ожидаемых ошибок
    /// при проверке на визуальное соответствие снимка (snapshot) тестируемого UIView (sut)
    /// ожидаемому изображению (reference)
    ///
    /// - Note: Универсальный метод. Позволяет сделать запись нового reference (в prepareReference).
    /// Сценарий определяет `mode`
    public static func matchErrors(
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line,
        matcher: SnapshotMatcherKind = .default,
        mode: SnapshotMode = .verify,
        deviceGroup: SnapshotDeviceGroup = .phone,
        expected: [SnapshotError?],
        prepareReference: @MainActor @escaping (SnapshotDevice) throws -> SnapshotSut,
        prepareSut: @MainActor @escaping (SnapshotDevice) throws -> SnapshotSut
    ) async {
        if case .record = mode {
            guard assertSimulatorIfNeeded(file: file, line: line) else { return }
        }

        let sutChecker = SnapshotSutChecker()

        var errors = await withTaskGroup(of: (Int, Error?).self, returning: [Error?].self) { group in
            for index in deviceGroup.devices.indices {
                let screen = deviceGroup.devices[index]
                group.addTask {
                    do {
                        let snapshot = try await Task { @MainActor in
                            let sut = try mode.prepareSnapshotView(
                                device: screen,
                                prepareReference: prepareReference,
                                prepareSut: prepareSut
                            )
                            try sutChecker.check(sut)
                            return try SnapshotCanvas(
                                sut: sut,
                                screen: screen
                            )
                            .capture()
                            .get(elseThrow: SnapshotError.snapshotRecordFailed)
                        }.value
                        let files = try SnapshotFiles(
                            device: screen,
                            testName: testName,
                            suffix: "",
                            testFile: file,
                            isComparisonFilesUseful: false
                        )
                        try await matcher.run(
                            snapshot: snapshot,
                            files: files,
                            mode: mode
                        )
                        return (index, nil)
                    } catch {
                        return (index, error)
                    }
                }
            }

            var result: [Error?] = Array(repeating: nil, count: deviceGroup.devices.count)
            while let next = await group.next() {
                result[next.0] = next.1
            }

            return result
        }
        switch mode {
        case .record:
            errors.append(SnapshotError.recordModeEnabled)
            for error in errors {
                XCTFail(Pretty.string(error), file: file, line: line)
            }
        case .verify:
            if sutChecker.isFailed {
                errors = [SnapshotError.sutReused]
            }
            let actual = errors.map { ($0 as? SnapshotError)?.reason ?? Pretty.string($0) }
            let expectedReasons = expected.map { $0?.reason ?? Pretty.string($0) }
            if actual != expectedReasons {
                assertSimulatorIfNeeded(file: file, line: line)
                let description = "Caught test errors must match expected, but" +
                    " got: \(actual)" +
                    " while expected: \(expectedReasons)"
                XCTFail(description, file: file, line: line)
            }
        }
    }

    /// Версия ``match()`` для ``SwiftUI.View``
    public static func match(
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line,
        matcher: SnapshotMatcherKind = .default,
        mode: SnapshotMode = .verify,
        deviceGroup: SnapshotDeviceGroup = .phone,
        includeAccessibility: Bool = false,
        prepareSut: @MainActor @escaping (SnapshotDevice) throws -> some SwiftUI.View
    ) async {
        await match(
            testName: testName,
            file: file,
            line: line,
            matcher: matcher,
            mode: mode,
            deviceGroup: deviceGroup,
            includeAccessibility: includeAccessibility,
            prepareSut: { device in
                try prepareSut(device).snapshotSut()
            }
        )
    }

    /// Снимает вью в двойную ширину девайса: половины с темами расставляет вызывающая сторона.
    public static func matchDualThemes(
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line,
        matcher: SnapshotMatcherKind = .default,
        mode: SnapshotMode = .verify,
        deviceGroup: SnapshotDeviceGroup = .phone,
        includeAccessibility: Bool = false,
        prepareSut: @Sendable @MainActor @escaping (SnapshotDevice) throws -> some SwiftUI.View
    ) async {
        await match(
            testName: testName,
            file: file,
            line: line,
            matcher: matcher,
            mode: mode,
            deviceGroup: deviceGroup.doubledWidth,
            includeAccessibility: includeAccessibility,
            prepareSut: prepareSut
        )
    }
}

extension SnapshotMode {
    @MainActor
    fileprivate func prepareSnapshotView(
        device: SnapshotDevice,
        prepareReference: @MainActor @escaping (SnapshotDevice) throws -> SnapshotSut,
        prepareSut: @MainActor @escaping (SnapshotDevice) throws -> SnapshotSut
    ) throws -> SnapshotSut {
        switch self {
        case .record:
            try prepareReference(device)
        case .verify:
            try prepareSut(device)
        }
    }
}

enum Pretty {
    static func string(_ value: Any?) -> String {
        guard let value else { return "null" }
        return String(describing: value)
    }
}
