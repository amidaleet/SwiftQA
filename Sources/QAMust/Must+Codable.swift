import Foundation
import PrettyDump

extension Must {
    public static func encode<T: Encodable>(
        _ model: T,
        to json: Any,
        file: StaticString = #filePath,
        line: UInt = #line,
        configure: (JSONEncoder) throws -> Void = { _ in }
    ) {
        do {
            let encoder = JSONEncoder()
            try configure(encoder)
            let data = try encoder.encode(model)
            let result = try JSONSerialization.jsonObject(with: data)
            Must.mirrorEqual(result, json, file: file, line: line)
        } catch {
            Must.fail(
                "Encountered failure while encoding model to compare: \(Pretty.string(error))",
                file: file,
                line: line
            )
        }
    }

    public static func decode<T: Decodable & Equatable>(
        _ json: Any,
        to model: T,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            let decoder = JSONDecoder()

            decoder.dateDecodingStrategy = dateDecodingStrategy

            let result = try decoder.decode(T.self, from: data)
            Must.equal(result, model, file: file, line: line)
        } catch {
            Must.fail(
                "Encountered failure while decoding model to compare: \(Pretty.string(error))",
                file: file,
                line: line
            )
        }
    }

    public static func failDecode<T: Decodable & Equatable>(
        _ json: Any,
        to _: T,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            let decoder = JSONDecoder()

            decoder.dateDecodingStrategy = dateDecodingStrategy
            _ = try decoder.decode(T.self, from: data)

            Must.fail("Decoding should have failed", file: file, line: line)
        } catch {
            return
        }
    }

    public static func decode<T: Decodable & Equatable>(
        _ json: String,
        to model: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let data = json.data(using: .utf8) else {
            Must.fail("Json string cannot be represented as data", file: file, line: line)
            return
        }

        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            Must.equal(result, model, file: file, line: line)
        } catch {
            Must.fail(
                "Encountered failure while decoding model to compare: \(Pretty.string(error))",
                file: file,
                line: line
            )
        }
    }
}
