import AppKit
import WindowCore

/// 각 기능이 메뉴에 항목을 꽂는 지점. 메뉴가 열릴 때마다 `menuItems()`가 다시 불린다.
@MainActor
protocol MenuContributor: AnyObject {
    var slot: MenuSectionSlot { get }
    func menuItems() -> [NSMenuItem]
}
