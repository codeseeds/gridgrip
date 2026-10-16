import Foundation

public enum AppSharedStoreError: Error, Equatable {
    case cycle(typeName: String)
}

/// 타입별 1개만 지연 생성해 보관한다 (`AppContext.shared`의 보관 로직).
/// 메인 스레드에서만 사용한다(잠금 없음).
public final class AppSharedStore {
    private var instances: [ObjectIdentifier: AnyObject] = [:]
    private var creating: Set<ObjectIdentifier> = []

    public init() {}

    /// 같은 타입은 같은 인스턴스를 돌려준다. `make` 안에서 다른 타입을 resolve해도 되지만,
    /// 생성 중인 타입을 다시 요청하면(직접·간접 순환) `cycle`을 throw한다.
    public func resolve<T: AnyObject>(_ type: T.Type, make: () -> T) throws -> T {
        let key = ObjectIdentifier(type)
        if let existing = instances[key] {
            return existing as! T
        }
        guard !creating.contains(key) else {
            throw AppSharedStoreError.cycle(typeName: String(reflecting: type))
        }
        creating.insert(key)
        defer { creating.remove(key) }
        let instance = make()
        instances[key] = instance
        return instance
    }
}
