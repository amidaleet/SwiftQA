import CoreGraphics
import Foundation

public struct SnapshotError: Error, Equatable, LocalizedError {
    /// Статичная часть, определяет "тип" ошибки
    public let reason: String

    /// Динамическая часть, полезная информация для контекста
    public let context: String

    public init(_ reason: String, context: String = "") {
        self.reason = reason
        self.context = context
    }

    public var errorDescription: String? {
        context.isEmpty ? reason : reason + " " + context
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.reason == rhs.reason
    }

    public static let snapshotRecordFailed: Self = SnapshotError("Не смогли записать snapshot изображение через UIKit")
    public static let recordModeEnabled: Self = SnapshotError("Включен .record режим. Для коммита кода нужно откатить тест на .verify (дефолт)")
    public static let sutReused: Self = SnapshotError("sut был переиспользован (возвращен 1 и тот же инстанс в prepareSut). Это искажает результат теста.")

    public static func corruptedPNGFile(_ path: URL) -> Self {
        SnapshotError("Не можем загрузить UIImage из referenceData с диска.", context: "Возможно битый файл: \(path.absoluteString)")
    }

    public static func differentImageSizes(_ size1: CGSize, _ size2: CGSize) -> Self {
        SnapshotError("Размеры snapshot и reference изображений не совпадают", context: "\(size1) != \(size2)")
    }

    public static let cannotCreateCGImage = SnapshotError("Не смогли получить CGImage из UIImage")

    public static func testFailed(_ mergePath: URL) -> Self {
        SnapshotError("Тест провален snapshot не совпал с reference.", context: "Смотри разницу наглядно в \(mergePath.absoluteString)")
    }
}
