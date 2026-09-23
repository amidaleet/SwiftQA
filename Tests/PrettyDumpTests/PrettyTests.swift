@testable import PrettyDump
import Testing

@Suite
struct PrettyTests {
    @Test
    func test_PrettyCollection() {
        #expect(Pretty.convert(Env.collection) == Env.prettyCollection)
    }

    @Test
    func test_PrettyDictionary() {
        #expect(Pretty.convert(Env.dictionary) == Env.prettyDictionary)
    }

    @Test
    func test_Tuple() {
        #expect(Pretty.convert(Env.tuple) == .dictionary([
            .string(".0"): .string(Env.tuple.0),
            .string(".1"): .string(Env.tuple.1),
        ]))
    }

    @Test
    func test_SimpleEnum() {
        #expect(Pretty.convert(Enumeration.dog) == .string("dog"))
    }

    @Test
    func test_AssociatedEnum() {
        #expect(Pretty.convert(Enumeration.cat(Env.barsik.rawValue, age: 5)) == .dictionary([
            .string("cat"): .dictionary([
                .string("age"): .int(5),
                .string(".0"): .string("barsik"),
            ]),
        ]))
    }

    @Test
    func test_PrettyEnum() {
        #expect(Pretty.convert(Enumeration.parrot(Env.oscar)) == .dictionary([
            .string("parrot"): .string("oscar"),
        ]))
    }

    @Test
    func test_Complex() {
        #expect(Pretty.convert(Env.complex) == Env.prettyComplex)
    }

    @Test
    func test_Print_String() {
        #expect(Pretty.string(Env.lamp) == Env.lamp)
    }

    @Test
    func test_Print_Number() {
        #expect(Pretty.string(Env.number) == String(describing: Env.number))
    }
}

private struct Place: RawRepresentable, PrettyRawConvertible, Hashable {
    let rawValue: String
}

private struct Animal: RawRepresentable, PrettyRawConvertible {
    let rawValue: String
}

private enum Enumeration {
    case dog
    case cat(String, age: Int)
    case parrot(Animal)
}

private enum Env {
    static let rug = Place(rawValue: "rug")
    static let sofa = Place(rawValue: "sofa")
    static let bobik = Animal(rawValue: "bobik")
    static let barsik = Animal(rawValue: "barsik")
    static let oscar = Animal(rawValue: "oscar")
    static let furniture = "furniture"
    static let light = "light"
    static let lamp = "lamp"
    static let chandelier = "chandelier"
    static let table = "table"
    static let cabinet = "cabinet"
    static let number = 1

    static let tuple = (lamp, chandelier)
    static let dictionary = [rug: bobik, sofa: barsik]
    static let collection = [bobik, barsik]

    nonisolated(unsafe) static let complex: [AnyHashable: Any] = [
        rug: bobik,
        sofa: barsik,
        furniture: [cabinet, table],
        light: [
            0: lamp,
            1: chandelier,
        ],
    ]

    static let prettyComplex: PrettyElement = .dictionary([
        .string(rug.rawValue): .string(bobik.rawValue),
        .string(sofa.rawValue): .string(barsik.rawValue),
        .string(furniture): .collection([
            .string(cabinet),
            .string(table),
        ]),
        .string(light): .dictionary([
            .int(0): .string(lamp),
            .int(1): .string(chandelier),
        ]),
    ])

    static let prettyCollection: PrettyElement = .collection([
        .string(bobik.rawValue),
        .string(barsik.rawValue),
    ])

    static let prettyDictionary: PrettyElement = .dictionary([
        .string(rug.rawValue): .string(bobik.rawValue),
        .string(sofa.rawValue): .string(barsik.rawValue),
    ])
}
