import Foundation
import XCTest

extension String {
    func localized(key: String, comment _: String, locale: String?, file _: StaticString = #file) -> String {
        do {
            return try preferredBundle(for: locale).localizedString(forKey: key, value: self, table: nil)
        } catch {
            XCTFail("Fail to find localization bundle, error: " + error.localizedDescription)
            return key
        }
    }

    private nonisolated(unsafe) static var assetsBundle: Bundle?
    private nonisolated(unsafe) static var localeToBundleMap: [String: Bundle] = [:]

    private func preferredBundle(for locale: String?) throws -> Bundle {
        let resourceBundle: Bundle

        if let known = Self.assetsBundle {
            resourceBundle = known
        } else {
            resourceBundle = try Bundle.snapshotsKitAssets()
            Self.assetsBundle = resourceBundle
        }

        guard let locale else {
            return resourceBundle
        }

        if let cachedBundle = Self.localeToBundleMap[locale] {
            return cachedBundle
        }

        guard let availableLocalizationBundles = resourceBundle.urls(forResourcesWithExtension: "lproj", subdirectory: nil) else {
            return resourceBundle
        }

        // Try to find an lproj for the exact locale.
        if let bundleURL = availableLocalizationBundles.first(where: { $0.lastPathComponent == "\(locale).lproj" }), let bundle = Bundle(url: bundleURL) {
            Self.localeToBundleMap[locale] = bundle
            return bundle
        }

        // If the locale specifies a region, try to find an lproj for the same language.
        let language = locale.prefix(2)
        if let bundleURL = availableLocalizationBundles.first(where: { $0.lastPathComponent.prefix(2) == language }), let bundle = Bundle(url: bundleURL) {
            Self.localeToBundleMap[locale] = bundle
            return bundle
        }

        return resourceBundle
    }
}
