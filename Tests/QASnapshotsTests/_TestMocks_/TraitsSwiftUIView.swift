import SwiftUI
import UIKit

/// Печатает size class из SwiftUI-окружения и запоминает их в ``box``
struct TraitsSwiftUIView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private static let unspecified = UIUserInterfaceSizeClass.unspecified.snapshotDescription

    let box = SizeClassBox()

    var body: some View {
        box.horizontalSizeClass = horizontalSizeClass
        box.verticalSizeClass = verticalSizeClass

        return Text(
            """
            SwiftUI
            horizontal: \(horizontalSizeClass?.snapshotDescription ?? Self.unspecified)
            vertical: \(verticalSizeClass?.snapshotDescription ?? Self.unspecified)
            """
        )
        .font(.system(size: 24))
        .foregroundStyle(.black)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
