import Foundation
import XCTest

extension Snapshots {
    /// Process-wide simulator requirement for `match` / `matchErrors`.
    ///
    /// Record always asserts before capture. Verify asserts only after a failed comparison.
    ///
    /// `nil` (the default) allows any simulator. A value set here wins over
    /// `QA_SNAPSHOTS_SIMULATOR`.
    ///
    /// Environment: `QA_SNAPSHOTS_SIMULATOR=iPhone17,3@26.5.0`
    /// (`SIMULATOR_MODEL_IDENTIFIER` + `@` + `major.minor.patch`).
    /// Optional `QA_SNAPSHOTS_SIMULATOR_HINT` is appended to the failure message.
    public static func requireSimulator(
        model: String,
        os: OperatingSystemVersion,
        hint: String? = nil
    ) {
        ResolvedSimulatorRequirement.lock.lock()
        let requirement = SimulatorRequirement(model: model, os: os, hint: hint)
        ResolvedSimulatorRequirement.processSharedValue = .required(requirement)
        ResolvedSimulatorRequirement.lock.unlock()
    }

    /// Clears a requirement set via `requireSimulator`. The environment variable still applies.
    public static func resetSimulatorRequirement() {
        ResolvedSimulatorRequirement.lock.lock()
        ResolvedSimulatorRequirement.processSharedValue = nil
        ResolvedSimulatorRequirement.lock.unlock()
    }

    @discardableResult
    static func assertSimulatorIfNeeded(file: StaticString, line: UInt) -> Bool {
        switch resolvedSimulatorRequirement() {
        case .any:
            return true
        case let .invalidEnvironment(raw):
            XCTFail(
                "Invalid QA_SNAPSHOTS_SIMULATOR=\(raw). Expected MODEL@major.minor.patch, e.g. iPhone17,3@26.5.0",
                file: file,
                line: line
            )
            return false
        case let .required(required):
            let process = ProcessInfo.processInfo
            let device = process.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
            let iosVersion = process.operatingSystemVersion

            if device == required.model, osMatches(iosVersion, required.os) {
                return true
            }

            var message = """
            ❌📱 Wrong iOS simulator!

            Your ENV: \(device) on \(osDescription(iosVersion))
            Valid ENV: \(required.model) on \(osDescription(required.os))
            """
            if let hint = required.hint, !hint.isEmpty {
                message += "\n\n\(hint)"
            }
            message += "\n\nSnapshot references are recorded with particular simulator version. Other devices break tests."
            XCTFail(message, file: file, line: line)
            return false
        }
    }

    private static func resolvedSimulatorRequirement() -> ResolvedSimulatorRequirement {
        ResolvedSimulatorRequirement.lock.lock()
        defer {
            ResolvedSimulatorRequirement.lock.unlock()
        }
        let resolved = ResolvedSimulatorRequirement.processSharedValue
        if let resolved {
            return resolved
        }

        let newValue: ResolvedSimulatorRequirement
        let env = ProcessInfo.processInfo.environment

        guard let raw = env["QA_SNAPSHOTS_SIMULATOR"], !raw.isEmpty else {
            newValue = .any
            ResolvedSimulatorRequirement.processSharedValue = newValue
            return newValue
        }
        guard let parsed = parseSimulatorEnvironment(raw) else {
            newValue = .invalidEnvironment(raw)
            ResolvedSimulatorRequirement.processSharedValue = newValue
            return newValue
        }

        newValue = .required(
            SimulatorRequirement(
                model: parsed.model,
                os: parsed.os,
                hint: env["QA_SNAPSHOTS_SIMULATOR_HINT"]
            )
        )
        ResolvedSimulatorRequirement.processSharedValue = newValue
        return newValue
    }
}

private enum ResolvedSimulatorRequirement {
    case any
    case invalidEnvironment(String)
    case required(SimulatorRequirement)

    static let lock = NSLock()
    nonisolated(unsafe) static var processSharedValue: ResolvedSimulatorRequirement?
}

private struct SimulatorRequirement: Sendable {
    var model: String
    var os: OperatingSystemVersion
    var hint: String?
}

private func parseSimulatorEnvironment(_ raw: String) -> (model: String, os: OperatingSystemVersion)? {
    guard let separator = raw.lastIndex(of: "@") else { return nil }
    let model = String(raw[..<separator])
    let osRaw = String(raw[raw.index(after: separator)...])
    guard !model.isEmpty, let os = parseOperatingSystemVersion(osRaw) else { return nil }
    return (model, os)
}

private func parseOperatingSystemVersion(_ raw: String) -> OperatingSystemVersion? {
    let parts = raw.split(separator: ".", omittingEmptySubsequences: false).compactMap { Int($0) }
    guard (1 ... 3).contains(parts.count) else { return nil }
    return OperatingSystemVersion(
        majorVersion: parts[0],
        minorVersion: parts.count > 1 ? parts[1] : 0,
        patchVersion: parts.count > 2 ? parts[2] : 0
    )
}

private func osMatches(_ lhs: OperatingSystemVersion, _ rhs: OperatingSystemVersion) -> Bool {
    lhs.majorVersion == rhs.majorVersion
        && lhs.minorVersion == rhs.minorVersion
        && lhs.patchVersion == rhs.patchVersion
}

private func osDescription(_ os: OperatingSystemVersion) -> String {
    "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
}
