/// 최신 1건 게이트. 실행 중에 온 요청은 대기 슬롯 1칸을 덮어써 중간 요청을 버린다.
/// 쓰기 실행기의 직렬 큐 안에서만 접근한다.
public struct LatestOnlyGate<Value> {
    private var pending: Value?

    public init() {}

    public var hasPending: Bool { pending != nil }

    /// 대기 슬롯에 넣거나 덮어쓴다. 슬롯이 비어 있다가 채워진 경우에만 true(= 실행 작업 1개를 예약하라).
    public mutating func submit(_ value: Value) -> Bool {
        let wasEmpty = pending == nil
        pending = value
        return wasEmpty
    }

    /// 슬롯 값을 꺼내고 비운다.
    public mutating func takeLatest() -> Value? {
        defer { pending = nil }
        return pending
    }
}
