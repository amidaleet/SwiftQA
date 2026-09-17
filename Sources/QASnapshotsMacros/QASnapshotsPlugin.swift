import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct QASnapshotsPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SnapshotSuiteMacro.self,
        SnapshotTestMacro.self,
        UnitTestMacro.self,
    ]
}
