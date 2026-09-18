import SwiftUI

public protocol SnapshotThemeApplying {
    @MainActor
    static func prepare(
        _ sut: some View,
        colorScheme: ColorScheme,
        device: SnapshotDevice
    ) -> AnyView
}

public enum DualThemeSnapshot {
    /// Вызов подставляет `@DualThemeSnapshotSuite`, руками его не пишут.
    @MainActor
    public static func make<Theme: SnapshotThemeApplying>(
        _ sut: some View,
        device: SnapshotDevice,
        theme: Theme.Type
    ) -> AnyView {
        AnyView(
            HStack(spacing: .zero) {
                theme.prepare(sut, colorScheme: .light, device: device)

                theme.prepare(sut, colorScheme: .dark, device: device)
            }
        )
    }
}
