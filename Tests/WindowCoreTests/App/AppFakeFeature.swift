import WindowCore

/// 테스트 공용 가짜 기능. 시작/정지 호출을 공유 기록 배열에 남긴다.
final class AppFakeFeature: AppFeature {
    struct StartError: Error {}

    final class Journal {
        var entries: [String] = []
    }

    let featureID: String
    let requiresAccessibility: Bool
    var shouldFailStart: Bool
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private let journal: Journal?

    init(_ id: String, requiresAccessibility: Bool = true, failsStart: Bool = false, journal: Journal? = nil) {
        self.featureID = id
        self.requiresAccessibility = requiresAccessibility
        self.shouldFailStart = failsStart
        self.journal = journal
    }

    func start() throws {
        startCount += 1
        if shouldFailStart { throw StartError() }
        journal?.entries.append("start:\(featureID)")
    }

    func stop() {
        stopCount += 1
        journal?.entries.append("stop:\(featureID)")
    }
}
