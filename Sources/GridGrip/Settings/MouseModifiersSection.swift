import AppKit
import os
import WindowCore

/// "마우스로 창 다루기" 섹션: 이동·크기조정 수정자 체크 5개씩 + 창 앞으로 가져오기 + 경고 줄.
/// 저장은 `MouseDragSettingsStore`로만 한다(키 `mouse.*` 직접 접근 금지). 규칙 판정은 `MouseModifierToggle`.
@MainActor
final class MouseModifiersSection: NSObject {
    private let store: MouseDragSettingsStore
    private let logger: Logger
    private var checkboxes: [ObjectIdentifier: (target: SettingsMouseTarget, modifier: MouseModifierSet)] = [:]
    private var buttons: [(button: NSButton, target: SettingsMouseTarget, modifier: MouseModifierSet)] = []
    private let bringToFrontCheckbox = NSButton(checkboxWithTitle: SettingsFormLayout.bringWindowToFrontTitle, target: nil, action: nil)
    private let warningLabel = SettingsLabels.warning()

    private(set) lazy var view: NSView = makeView()

    init(store: MouseDragSettingsStore, logger: Logger) {
        self.store = store
        self.logger = logger
    }

    /// 저장소의 실제 값으로 다시 그린다. 경고 줄은 지우지 않는다(방금 거부된 이유를 남겨 둔다).
    func refresh() {
        let settings = store.load()
        for entry in buttons {
            let set = entry.target == .move ? settings.moveModifiers : settings.resizeModifiers
            entry.button.state = set.contains(entry.modifier) ? .on : .off
        }
        bringToFrontCheckbox.state = settings.bringWindowToFront ? .on : .off
    }

    private func makeView() -> NSView {
        var rows: [[NSView]] = []
        for row in SettingsFormLayout.mouseRows {
            var cells: [NSView] = [SettingsLabels.rowTitle(row.title + ":")]
            for modifier in SettingsFormLayout.mouseModifierOrder {
                let button = NSButton(checkboxWithTitle: SettingsFormLayout.label(for: modifier), target: self, action: #selector(modifierToggled(_:)))
                checkboxes[ObjectIdentifier(button)] = (row.target, modifier)
                buttons.append((button, row.target, modifier))
                cells.append(button)
            }
            rows.append(cells)
        }
        let grid = NSGridView(views: rows)
        grid.column(at: 0).xPlacement = .trailing
        grid.rowSpacing = 6
        grid.columnSpacing = 10

        bringToFrontCheckbox.target = self
        bringToFrontCheckbox.action = #selector(bringToFrontToggled(_:))

        let stack = NSStackView(views: [grid, bringToFrontCheckbox, warningLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        refresh()
        return stack
    }

    @objc private func modifierToggled(_ sender: NSButton) {
        guard let entry = checkboxes[ObjectIdentifier(sender)] else { return }
        switch MouseModifierToggle.apply(store.load(), target: entry.target, modifier: entry.modifier, isOn: sender.state == .on) {
        case let .accepted(settings):
            save(settings)
        case let .rejected(error):
            warningLabel.stringValue = "⚠ " + SettingsFormLayout.message(for: error)
            refresh()
        }
    }

    @objc private func bringToFrontToggled(_ sender: NSButton) {
        var settings = store.load()
        settings.bringWindowToFront = sender.state == .on
        save(settings)
    }

    /// 사전 검증을 통과한 값만 오므로 실패 가능성은 낮다. 실패하면 로그 1줄 + 실제 저장값으로 다시 그린다.
    private func save(_ settings: MouseDragSettings) {
        do {
            try store.save(settings)
            warningLabel.stringValue = ""
        } catch {
            logger.error("마우스 설정 저장 실패: \(String(describing: error), privacy: .public)")
        }
        refresh()
    }
}

/// 설정 창 공용 라벨.
@MainActor
enum SettingsLabels {
    static func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    static func rowTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }

    /// 평소 비어 있는 경고 줄.
    static func warning() -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: "")
        label.textColor = .systemOrange
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.preferredMaxLayoutWidth = 560
        return label
    }
}
