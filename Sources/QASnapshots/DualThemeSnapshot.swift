import SwiftUI

public protocol SnapshotThemeApplying {
    /// `device` — девайс, на котором показана вью: в двухтемном кадре это его половина,
    /// в однотемном — весь кадр. Делить ширину пополам теме не нужно.
    @MainActor
    static func prepare(
        _ sut: some View,
        colorScheme: ColorScheme,
        device: SnapshotDevice
    ) -> AnyView
}

public enum DualThemeSnapshot {
    /// Вызов подставляет `@DualThemeSnapshotSuite`, руками его не пишут.
    /// `device` — кадр двойной ширины, тема получает его половину.
    @MainActor
    public static func make<Theme: SnapshotThemeApplying>(
        _ sut: some View,
        device: SnapshotDevice,
        theme: Theme.Type
    ) -> AnyView {
        let half = device.halfWidth

        return AnyView(
            HStack(spacing: .zero) {
                theme.prepare(sut, colorScheme: .light, device: half)

                theme.prepare(sut, colorScheme: .dark, device: half)
            }
        )
    }
}
