import XCTest
import WindowCore

private final class AppStoreProbeX {}
private final class AppStoreProbeY {}

final class AppSharedStoreTests: XCTestCase {
    // 
    func testCycleThrows() throws {
        let store = AppSharedStore()
        var innerError: Error?
        var makeCount = 0

        let outer = try store.resolve(AppStoreProbeX.self) {
            makeCount += 1
            do {
                _ = try store.resolve(AppStoreProbeX.self) { AppStoreProbeX() }
            } catch {
                innerError = error
            }
            return AppStoreProbeX()
        }

        guard case let .cycle(typeName)? = innerError as? AppSharedStoreError else {
            return XCTFail("순환 오류가 나지 않음: \(String(describing: innerError))")
        }
        XCTAssertTrue(typeName.contains("AppStoreProbeX"), typeName)
        let again = try store.resolve(AppStoreProbeX.self) {
            makeCount += 1
            return AppStoreProbeX()
        }
        XCTAssertTrue(outer === again)
        XCTAssertEqual(makeCount, 1)
    }

    // 
    func testIndirectCycleThrows() throws {
        let store = AppSharedStore()
        var innerError: Error?

        let x = try store.resolve(AppStoreProbeX.self) {
            _ = try? store.resolve(AppStoreProbeY.self) {
                do {
                    _ = try store.resolve(AppStoreProbeX.self) { AppStoreProbeX() }
                } catch {
                    innerError = error
                }
                return AppStoreProbeY()
            }
            return AppStoreProbeX()
        }

        guard case let .cycle(typeName)? = innerError as? AppSharedStoreError else {
            return XCTFail("간접 순환 오류가 나지 않음: \(String(describing: innerError))")
        }
        XCTAssertTrue(typeName.contains("AppStoreProbeX"), typeName)
        XCTAssertTrue(try store.resolve(AppStoreProbeX.self) { AppStoreProbeX() } === x)
    }

    func testSameInstancePerType() throws {
        let store = AppSharedStore()
        var xMakeCount = 0
        let makeX: () -> AppStoreProbeX = {
            xMakeCount += 1
            return AppStoreProbeX()
        }

        let x1 = try store.resolve(AppStoreProbeX.self, make: makeX)
        let x2 = try store.resolve(AppStoreProbeX.self, make: makeX)
        XCTAssertTrue(x1 === x2)
        XCTAssertEqual(xMakeCount, 1)

        var xInsideY: AppStoreProbeX?
        var innerError: Error?
        let y = try store.resolve(AppStoreProbeY.self) {
            do {
                xInsideY = try store.resolve(AppStoreProbeX.self, make: makeX)
            } catch {
                innerError = error
            }
            return AppStoreProbeY()
        }
        XCTAssertNil(innerError)
        XCTAssertTrue(xInsideY === x1)
        XCTAssertEqual(xMakeCount, 1)
        XCTAssertFalse((x1 as AnyObject) === (y as AnyObject))
    }
}
