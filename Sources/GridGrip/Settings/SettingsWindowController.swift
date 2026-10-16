import AppKit
import os
import WindowCore

/// 설정 창(앱 실행 중 1개 — `ctx.settingsWindowController`로만 얻는다). 창과 뷰는 처음 열 때 만든다.
/// 섹션 순서·문구는 `SettingsFormLayout`이 정본이다. 모든 변경은 즉시 저장된다(저장 버튼 없음).
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate, ShortcutRecorderViewDelegate {
    private let engine: ShortcutEngine
    private let activation: ActivationPolicy
    private let defaults: UserDefaults
    private let logger: Logger
    private let loginItems = LoginItemService()

    private var recorders: [WindowAction: ShortcutRecorderView] = [:]
    private let shortcutWarningLabel = SettingsLabels.warning()
    /// 겹침·수정자 없음·시스템 조합 거부 같은 방금 일어난 녹화 경고. 다음 녹화 시작·확정 때 지운다.
    private var recordingMessage: String?
    private lazy var mouseSection = MouseModifiersSection(store: mouseStore, logger: logger)
    private lazy var excludedSection = ExcludedAppsSection(activation: activation)
    private let loginCheckbox = NSButton(checkboxWithTitle: SettingsFormLayout.loginItemTitle, target: nil, action: nil)
    private let loginMessageLabel = SettingsLabels.warning()
    private let openLoginSettingsButton = NSButton(title: SettingsFormLayout.openSystemSettingsTitle, target: nil, action: nil)
    /// 직전 토글 결과(실패 문구 유지용). 창을 새로 열면 지운다.
    private var lastLoginToggle: LoginItemPresentation?
    private var defaultsObserver: NSObjectProtocol?
    /// nib이 없으므로 `window`를 처음 만들었는지는 이 값으로만 판단한다(`window` 접근이 nib 로드를 시도하지 않게).
    private var didBuildWindow = false

    private var mouseStore: MouseDragSettingsStore { MouseDragSettingsStore(defaults: defaults) }

    init(engine: ShortcutEngine, activation: ActivationPolicy, defaults: UserDefaults, logger: Logger) {
        self.engine = engine
        self.activation = activation
        self.defaults = defaults
        self.logger = logger
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 창이 없으면 만들고, 있으면 재사용해 맨 앞으로. 메뉴바 전용 앱은 활성화해야 창이 다른 앱 앞에 뜬다.
    func showWindow() {
        if !didBuildWindow {
            window = buildWindow()
            didBuildWindow = true
        }
        lastLoginToggle = nil
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// 창을 아직 만들지 않았으면 아무것도 하지 않는다(시작 시 창 생성 방지).
    func refresh() {
        guard didBuildWindow else { return }
        for (action, recorder) in recorders {
            recorder.combo = engine.bindings[action]
            recorder.hasWarning = engine.registrationFailures.contains(action)
        }
        updateShortcutWarning()
        mouseSection.refresh()
        excludedSection.refresh()
        refreshLoginItem()
    }

    // MARK: - 창 구성

    private func buildWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = SettingsFormLayout.windowTitle
        window.isReleasedWhenClosed = false
        window.delegate = self

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let horizontalInsets = stack.edgeInsets.left + stack.edgeInsets.right

        for (index, section) in SettingsFormLayout.sections.enumerated() {
            if index > 0 {
                let separator = NSBox()
                separator.boxType = .separator
                stack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -horizontalInsets).isActive = true
            }
            if let title = section.title {
                stack.addArrangedSubview(SettingsLabels.sectionTitle(title))
            }
            let content = view(for: section)
            stack.addArrangedSubview(content)
            // 세로 스택은 내용이 오른쪽 여백을 넘어도 막지 않는다. 모든 섹션을 구분선 폭 안에 두고,
            // 오른쪽 끝을 쓰는 섹션(제외 앱 표, 로그인·기본값 복원 줄)은 구분선과 같은 폭으로 맞춘다.
            if section == .excludedApps || section == .general {
                content.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -horizontalInsets).isActive = true
            } else {
                content.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -horizontalInsets).isActive = true
            }
        }

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        window.contentView = container
        container.layoutSubtreeIfNeeded()
        window.setContentSize(container.fittingSize)
        window.center()

        excludedSection.hostWindow = window
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseSection.refresh() }
        }
        return window
    }

    private func view(for section: SettingsSection) -> NSView {
        switch section {
        case .shortcuts: return makeShortcutsView()
        case .mouse: return mouseSection.view
        case .excludedApps: return excludedSection.view
        case .general: return makeGeneralView()
        }
    }

    private func makeShortcutsView() -> NSView {
        let rows: [[NSView]] = SettingsFormLayout.shortcutGrid.map { pair in
            pair.flatMap { action -> [NSView] in
                let recorder = ShortcutRecorderView(action: action)
                recorder.delegate = self
                recorders[action] = recorder
                return [SettingsLabels.rowTitle(SettingsFormLayout.title(for: action) + ":"), recorder]
            }
        }
        let grid = NSGridView(views: rows)
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 2).xPlacement = .trailing
        grid.rowSpacing = 6
        grid.columnSpacing = 8
        for row in 0..<grid.numberOfRows {
            grid.row(at: row).yPlacement = .center
        }

        let stack = NSStackView(views: [grid, shortcutWarningLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func makeGeneralView() -> NSView {
        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginItemToggled(_:))
        openLoginSettingsButton.target = self
        openLoginSettingsButton.action = #selector(openLoginItemSettings(_:))
        let restoreButton = NSButton(title: SettingsFormLayout.restoreDefaultsTitle, target: self, action: #selector(restoreDefaultsClicked(_:)))

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let topRow = NSStackView(views: [loginCheckbox, spacer, restoreButton])
        topRow.orientation = .horizontal

        let stack = NSStackView(views: [topRow, loginMessageLabel, openLoginSettingsButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        topRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func updateShortcutWarning() {
        var lines: [String] = []
        if let recordingMessage {
            lines.append("⚠ " + recordingMessage)
        }
        let failed = SettingsFormLayout.warningActions(registrationFailures: engine.registrationFailures)
        if !failed.isEmpty {
            let names = failed.map(SettingsFormLayout.title(for:)).joined(separator: ", ")
            lines.append("⚠ \(names): \(SettingsFormLayout.registrationFailureMessage)")
        }
        shortcutWarningLabel.stringValue = lines.joined(separator: "\n")
        fitWindowToContent()
    }

    /// 경고 줄·로그인 안내가 나타나거나 사라지면 창 높이를 내용에 맞춘다(위쪽 가장자리는 그대로).
    /// 맞추지 않으면 남는 높이가 단축키 격자 줄 사이에 끼어 간격이 벌어진다.
    private func fitWindowToContent() {
        guard didBuildWindow, let window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        guard size != content.frame.size else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true)
    }

    // MARK: - 로그인 항목

    private func refreshLoginItem() {
        var presentation = LoginItemPresentation.make(loginItems.status)
        if let lastLoginToggle, lastLoginToggle.isChecked == presentation.isChecked {
            presentation.message = lastLoginToggle.message
        }
        apply(presentation)
    }

    private func apply(_ presentation: LoginItemPresentation) {
        loginCheckbox.state = presentation.isChecked ? .on : .off
        loginCheckbox.isEnabled = presentation.isEnabled
        loginMessageLabel.stringValue = presentation.message ?? ""
        loginMessageLabel.isHidden = presentation.message == nil
        openLoginSettingsButton.isHidden = !presentation.showsOpenSettings
        fitWindowToContent()
    }

    @objc private func loginItemToggled(_ sender: NSButton) {
        let result = loginItems.setEnabled(sender.state == .on)
        if let error = result.errorDescription {
            logger.error("로그인 항목 변경 실패: \(error, privacy: .public)")
        }
        let presentation = LoginItemPresentation.afterToggle(actual: result.status, errorDescription: result.errorDescription)
        lastLoginToggle = presentation
        apply(presentation)
    }

    @objc private func openLoginItemSettings(_ sender: NSButton) {
        loginItems.openSystemSettings()
    }

    // MARK: - 기본값 복원

    @objc private func restoreDefaultsClicked(_ sender: NSButton) {
        guard didBuildWindow, let window else { return }
        let alert = NSAlert()
        alert.messageText = L10n.tr("Restore defaults?")
        alert.informativeText = SettingsFormLayout.restoreDefaultsConfirmation
        alert.addButton(withTitle: L10n.tr("Cancel"))
        alert.addButton(withTitle: L10n.tr("Restore"))
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertSecondButtonReturn else { return }
            do {
                try SettingsDefaultsRestorer.restoreAll(engine: self.engine, mouseStore: self.mouseStore)
            } catch {
                self.logger.error("기본값 복원 중 마우스 설정 저장 실패: \(String(describing: error), privacy: .public)")
            }
            self.recordingMessage = nil
            self.refresh()
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        for recorder in recorders.values {
            recorder.endRecording(reason: .windowClosed)
        }
    }

    // MARK: - ShortcutRecorderViewDelegate

    func recorderDidBeginRecording(_ recorder: ShortcutRecorderView) {
        // 녹화 중에는 기존 조합을 눌러도 창이 움직이지 않고 칸에 녹화되게 한다.
        engine.suspend(.recording)
        recordingMessage = nil
        updateShortcutWarning()
    }

    func recorderDidEndRecording(_ recorder: ShortcutRecorderView, reason: ShortcutRecordingEndReason) {
        // 다른 사유(.userPaused·.excludedAppFrontmost)가 남아 있으면 엔진이 재등록하지 않는다.
        engine.resume(.recording)
        recorder.combo = engine.bindings[recorder.action]
    }

    func recorder(_ recorder: ShortcutRecorderView, didCommit combo: KeyCombo) {
        switch engine.setShortcut(combo, for: recorder.action) {
        case .applied:
            recordingMessage = SettingsFormLayout.advisory(for: combo)
            recorder.endRecording(reason: .committed)
            refresh()
        case .invalidModifiers:
            // 판정 함수가 넘긴 시스템 필수 조합 등. 수정자 부족 거부와 같이 경고음 + 안내 + 녹화 계속.
            NSSound.beep()
            recordingMessage = ShortcutValidator.isReserved(combo)
                ? SettingsFormLayout.reservedComboMessage
                : SettingsFormLayout.noModifierMessage
            updateShortcutWarning()
        case let .conflict(actions):
            // 같은 이벤트 처리 안에서 즉시 경고 → 시트(기본 버튼 [취소]).
            recordingMessage = SettingsFormLayout.conflictMessage(actions)
            updateShortcutWarning()
            presentConflictSheet(for: recorder, combo: combo, conflicts: actions)
        }
    }

    func recorderDidRequestClear(_ recorder: ShortcutRecorderView) {
        engine.setShortcut(nil, for: recorder.action)
        recordingMessage = nil
        refresh()
    }

    func recorderDidRejectNoModifier(_ recorder: ShortcutRecorderView) {
        recordingMessage = SettingsFormLayout.noModifierMessage
        updateShortcutWarning()
    }

    func recorderNeedsConflictDismissal(_ recorder: ShortcutRecorderView) {
        guard didBuildWindow, let window, let sheet = window.attachedSheet else { return }
        window.endSheet(sheet, returnCode: .cancel)
    }

    private func presentConflictSheet(for recorder: ShortcutRecorderView, combo: KeyCombo, conflicts: [WindowAction]) {
        guard didBuildWindow, let window else {
            recorder.endRecording(reason: .cancelled)
            return
        }
        let names = conflicts.map(SettingsFormLayout.title(for:)).joined(separator: "', '")
        let alert = NSAlert()
        alert.messageText = SettingsFormLayout.conflictMessage(conflicts)
        alert.informativeText = L10n.tr("To use %1$@ for '%2$@', the shortcut for '%3$@' must be cleared.",
                                        combo.displayString, SettingsFormLayout.title(for: recorder.action), names)
        alert.addButton(withTitle: L10n.tr("Cancel"))  // 첫 버튼 = 기본(Return). 실수로 Return을 눌러도 다른 동작이 지워지지 않는다.
        alert.addButton(withTitle: L10n.tr("Replace — clears the shortcut for '%@'", names))

        // 시트가 붙으면 녹화 칸이 포커스를 잃는다. 이 동안은 녹화 종료로 보지 않는다.
        recorder.isAwaitingConflictDecision = true
        alert.beginSheetModal(for: window) { [weak self, weak recorder] response in
            guard let self, let recorder else { return }
            recorder.isAwaitingConflictDecision = false
            if response == .alertSecondButtonReturn, recorder.isRecording {
                self.engine.setShortcut(combo, for: recorder.action, replacingConflicts: true)
                self.recordingMessage = SettingsFormLayout.advisory(for: combo)
            }
            recorder.endRecording(reason: .conflictResolved)
            self.refresh()
        }
    }
}
