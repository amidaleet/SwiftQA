import SwiftUI

/// Size class из SwiftUI-окружения последнего рендера ``TraitsSwiftUIView``
@MainActor
final class SizeClassBox {
    var horizontalSizeClass: UserInterfaceSizeClass?
    var verticalSizeClass: UserInterfaceSizeClass?
}
