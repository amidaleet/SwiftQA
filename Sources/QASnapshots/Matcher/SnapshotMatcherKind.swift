import UIKit

/// Временная опция выбора между алгоритмами сравнения изобращений
public enum SnapshotMatcherKind: Sendable {
    /// Алгоритм "в лоб", сравниваем цвета всех пикселей
    /// - рисуем битмап в размере pointsSize (БЕЗ учета scale)
    /// - считаем delta RGBA компонент
    /// - считаем число поехавших по цвету __точек__ к их общему числу (pointsSize)
    /// - для быстроты, параллелим сравнение по Task
    case pointColorDiffConcurrent

    /// `pointColorDiffConcurrent` но с вычислением на базе Metal shader
    case pointColorDiffMetal

    /// Используемый во всех продуктовых тестах алгоритм
    public static let `default`: Self = .pointColorDiffConcurrent
}

extension SnapshotMatcherKind {
    @concurrent
    func run(
        snapshot: UIImage,
        files: SnapshotFiles,
        mode: SnapshotMode
    ) async throws {
        switch self {
        case .pointColorDiffConcurrent:
            try await SnapshotMatcherV4(
                snapshot: snapshot,
                files: files,
                mode: mode
            ).run()
        case .pointColorDiffMetal:
            try await SnapshotMatcherV5(
                snapshot: snapshot,
                files: files,
                mode: mode
            ).run()
        }
    }
}
