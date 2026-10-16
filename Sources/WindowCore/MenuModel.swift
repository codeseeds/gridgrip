import Foundation

/// 메뉴 섹션 순서 (값 변경 금지).
/// permission(권한 안내 줄·시스템 설정 열기), arrange(9칸·전체화면 채우기·모니터 이동),
/// history(되돌리기/다시하기), control(끄기 ▸), preferences(정보·설정…·로그인 시 실행),
/// app(종료).
public enum MenuSectionSlot: Int, CaseIterable, Comparable {
    case permission = 0
    case arrange = 10
    case history = 20
    case control = 30
    case preferences = 40
    case app = 100

    public static func < (lhs: MenuSectionSlot, rhs: MenuSectionSlot) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct MenuModifiers: OptionSet, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = MenuModifiers(rawValue: 1 << 0)
    public static let option = MenuModifiers(rawValue: 1 << 1)
    public static let shift = MenuModifiers(rawValue: 1 << 2)
    public static let control = MenuModifiers(rawValue: 1 << 3)
}

/// AppKit 비의존 메뉴 항목 기술.
public struct MenuItemSpec: Equatable {
    public let id: String
    public let title: String
    public let keyEquivalent: String
    public let modifiers: MenuModifiers
    public let isEnabled: Bool

    public init(id: String, title: String, keyEquivalent: String = "", modifiers: MenuModifiers = [], isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }
}

public enum MenuEntry<T> {
    case item(T)
    case separator
}

extension MenuEntry: Equatable where T: Equatable {}

public enum MenuLayout {
    /// 슬롯 순서로 정렬하고, 빈 섹션은 생략하며, 비어 있지 않은 섹션 사이에만 구분선을 넣는다.
    public static func compose<T>(_ sections: [MenuSectionSlot: [T]]) -> [MenuEntry<T>] {
        var entries: [MenuEntry<T>] = []
        for slot in MenuSectionSlot.allCases {
            guard let items = sections[slot], !items.isEmpty else { continue }
            if !entries.isEmpty { entries.append(.separator) }
            entries.append(contentsOf: items.map { .item($0) })
        }
        return entries
    }
}

/// 기본 메뉴 항목 정본.
public enum BaseMenuSpec {
    public static let permissionWarningID = "permission.warning"
    public static let openSystemSettingsID = "permission.openSystemSettings"
    public static let quitID = "app.quit"

    public static func permissionSection(_ state: PermissionState) -> [MenuItemSpec] {
        switch state {
        case .granted:
            return []
        case .denied:
            return [
                MenuItemSpec(id: permissionWarningID, title: "⚠︎ 손쉬운 사용 권한이 필요합니다", isEnabled: false),
                MenuItemSpec(id: openSystemSettingsID, title: "시스템 설정 열기…"),
            ]
        }
    }

    public static func appSection() -> [MenuItemSpec] {
        [MenuItemSpec(id: quitID, title: "\(AppIdentity.displayName) 종료", keyEquivalent: "q", modifiers: [.command])]
    }
}
