import Foundation
import XCTest
import WindowCore

final class L10nTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // App
        .deletingLastPathComponent() // WindowCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // 저장소 루트
    private static let localizationDir = root.appendingPathComponent("Support/Localization")

    override func tearDown() {
        L10n.bundle = .main
        super.tearDown()
    }

    func testEnglishSourceTextIsReturnedWithoutTranslation() {
        XCTAssertEqual(L10n.tr("Settings…"), "Settings…")
        XCTAssertEqual(L10n.tr("Quit %@", "GridGrip"), "Quit GridGrip")
    }

    func testKoreanTranslationIsUsedFromKoreanBundle() throws {
        L10n.bundle = try XCTUnwrap(Bundle(url: Self.localizationDir.appendingPathComponent("ko.lproj")))
        XCTAssertEqual(L10n.tr("Settings…"), "설정…")
        XCTAssertEqual(L10n.tr("Quit %@", "GridGrip"), "GridGrip 종료")
        XCTAssertEqual(L10n.tr("Not in the table"), "Not in the table")
    }

    /// 소스의 `L10n.tr("…")` 키가 한국어 표에 모두 있고, 표에 남는 키가 없으며, 서식 지정자가 같아야 한다.
    func testKoreanTableMatchesKeysUsedInSources() throws {
        let used = try Self.keysUsedInSources()
        XCTAssertFalse(used.isEmpty)
        let korean = try Self.table("ko")

        XCTAssertEqual(Set(korean.keys).subtracting(used).sorted(), [], "한국어 표에만 있는 키")
        XCTAssertEqual(used.subtracting(korean.keys).sorted(), [], "번역 없는 키")
        for (key, value) in korean {
            XCTAssertEqual(Self.specifiers(in: value), Self.specifiers(in: key), "서식 지정자 불일치: \(key)")
        }
    }

    func testEnglishTableExistsSoEnglishIsAnAvailableLocalization() throws {
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: Self.localizationDir.appendingPathComponent("en.lproj/Localizable.strings").path))
    }

    /// 화면 문구는 모두 `L10n.tr` 을 거친다. 주석·로그·개발자용 오류 문구는 대상이 아니다.
    func testNoHardcodedKoreanUserFacingStrings() throws {
        let hangulLiteral = try NSRegularExpression(pattern: #""[^"\n]*[가-힣][^"\n]*""#)
        let exempt = ["logger.", "preconditionFailure(", "fatalError(", "debugDescription:"]
        var offenders: [String] = []
        for file in try Self.sourceFiles() {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let code = line.components(separatedBy: "//").first ?? line
                guard !code.trimmingCharacters(in: .whitespaces).isEmpty,
                      !exempt.contains(where: code.contains) else { continue }
                if hangulLiteral.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil {
                    offenders.append("\(file.lastPathComponent):\(index + 1)")
                }
            }
        }
        XCTAssertEqual(offenders, [])
    }

    // MARK: - 도우미

    private static func sourceFiles() throws -> [URL] {
        let sources = root.appendingPathComponent("Sources")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    private static func keysUsedInSources() throws -> Set<String> {
        let call = try NSRegularExpression(pattern: #"L10n\.tr\(\s*"((?:[^"\\]|\\.)*)""#)
        var keys: Set<String> = []
        for file in try sourceFiles() {
            // 주석(문서 주석의 예시 포함)은 빼고 코드만 본다.
            let text = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            for match in call.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let literal = String(text[Range(match.range(at: 1), in: text)!])
                keys.insert(literal.replacingOccurrences(of: #"\""#, with: "\"").replacingOccurrences(of: #"\\"#, with: #"\"#))
            }
        }
        return keys
    }

    private static func table(_ language: String) throws -> [String: String] {
        let url = localizationDir.appendingPathComponent("\(language).lproj/Localizable.strings")
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
    }

    private static func specifiers(in text: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: #"%(\d+\$)?@"#)
        return pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { String(text[Range($0.range, in: text)!]) }
            .sorted()
    }
}
