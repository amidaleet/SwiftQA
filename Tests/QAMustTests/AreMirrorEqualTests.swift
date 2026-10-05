import Foundation
import QAMust
import XCTest

final class AreMirrorEqualTests: XCTestCase {
    func test_Struct_SameFields_Equal() {
        Must.beTrue(areMirrorEqual(Person(name: "a"), Person(name: "a")))
    }

    func test_Struct_DifferentFieldLength_NotEqual() {
        Must.beTrue(!areMirrorEqual(Person(name: "a"), Person(name: "ab")))
    }

    func test_NestedStruct() {
        let match = Wrapper(person: Person(name: "a"))
        Must.beTrue(areMirrorEqual(match, Wrapper(person: Person(name: "a"))))
        Must.beTrue(!areMirrorEqual(match, Wrapper(person: Person(name: "ab"))))
    }

    func test_Class_IgnoresIdentity() {
        Must.beTrue(areMirrorEqual(Node(title: "a"), Node(title: "a")))
        Must.beTrue(!areMirrorEqual(Node(title: "a"), Node(title: "ab")))
    }

    func test_MirrorEquatable_UsesAreMirrorEqual() {
        Must.beTrue(Person(name: "a") == Person(name: "a"))
        Must.beTrue(Person(name: "a") != Person(name: "ab"))
    }

    func test_Optional_NilMatchesOnlyNil() {
        Must.beTrue(areMirrorEqual(nil as Person?, nil as Person?))
        Must.beTrue(!areMirrorEqual(Person(name: "a") as Person?, nil))
    }

    func test_Array_MatchesByPosition() {
        Must.beTrue(areMirrorEqual([Person(name: "a")], [Person(name: "a")]))
        Must.beTrue(!areMirrorEqual([Person(name: "a")], [Person(name: "a"), Person(name: "b")]))
        Must.beTrue(!areMirrorEqual([Person(name: "a")], [Person(name: "ab")]))
    }

    func test_Dictionary_MatchesByKey() {
        let left = ["a": Person(name: "x"), "ab": Person(name: "y")]
        let right = ["ab": Person(name: "y"), "a": Person(name: "x")]
        Must.beTrue(areMirrorEqual(left, right))
        Must.beTrue(!areMirrorEqual(left, ["a": Person(name: "x")]))
        Must.beTrue(!areMirrorEqual(left, ["a": Person(name: "xx"), "ab": Person(name: "y")]))
    }

    func test_Set_IgnoresOrder() {
        Must.beTrue(areMirrorEqual(Set(["a", "ab"]), Set(["ab", "a"])))
        Must.beTrue(!areMirrorEqual(Set(["a"]), Set(["ab"])))
    }

    func test_Enum_CaseName() {
        Must.beTrue(areMirrorEqual(Side.left, Side.left))
        Must.beTrue(!areMirrorEqual(Side.left, Side.right))
    }

    func test_Enum_AssociatedValue() {
        Must.beTrue(areMirrorEqual(Action.tap("a"), Action.tap("a")))
        Must.beTrue(!areMirrorEqual(Action.tap("a"), Action.tap("ab")))
        Must.beTrue(!areMirrorEqual(Action.tap("a"), Action.swipe("a")))
    }

    func test_AnyHashable_UsesEquatable() {
        Must.beTrue(areMirrorEqual(Tagged(id: 1), Tagged(id: 1)))
        Must.beTrue(!areMirrorEqual(Tagged(id: 1), Tagged(id: 2)))
    }

    func test_AlwaysEqualToSameMetatype_ContinuesComparisonIfSelfMatches_IgnoresNestedChildren() {
        Must.beTrue(areMirrorEqual(Marked(mark: Mark(value: 1), title: "a"), Marked(mark: Mark(value: 200), title: "a")))
        Must.beTrue(!areMirrorEqual(Marked(mark: Mark(value: 1), title: "a"), Marked(mark: OtherMark(), title: "a")))
    }

    func test_UnfairLockPointer_SkippedInComparison() {
        let leftLock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        let rightLock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        leftLock.initialize(to: os_unfair_lock())
        rightLock.initialize(to: os_unfair_lock())
        defer {
            leftLock.deinitialize(count: 1)
            rightLock.deinitialize(count: 1)
            leftLock.deallocate()
            rightLock.deallocate()
        }

        Must.beTrue(areMirrorEqual(Locked(lock: leftLock, title: "a"), Locked(lock: rightLock, title: "a")))
        Must.beTrue(!areMirrorEqual(Locked(lock: leftLock, title: "a"), Locked(lock: rightLock, title: "b")))
    }
}

private struct Person: MirrorEquatable {
    var name: String
}

private struct Wrapper {
    var person: Person
}

private final class Node {
    var title: String

    init(title: String) {
        self.title = title
    }
}

private enum Side {
    case left
    case right
}

private enum Action {
    case tap(String)
    case swipe(String)
}

private struct Tagged {
    var id: AnyHashable
}

private struct Mark: AlwaysEqualToSameMetatypeInMirror {
    var value: Int
}

private struct OtherMark: AlwaysEqualToSameMetatypeInMirror {}

private struct Marked {
    var mark: any AlwaysEqualToSameMetatypeInMirror
    var title: String
}

private struct Locked {
    var lock: UnsafeMutablePointer<os_unfair_lock>
    var title: String
}
