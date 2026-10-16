import AppKit
import WindowCore

/// 녹화 종료 경로 7가지. 모두 `ShortcutRecorderView.endRecording(reason:)` 한 함수로 모인다.
enum ShortcutRecordingEndReason {
    case committed
    case cancelled
    case cleared
    /// 다른 칸·다른 컨트롤 클릭(첫 응답자 상실 포함)
    case lostFocus
    /// 다른 앱으로 전환
    case appDeactivated
    case windowClosed
    /// 겹침 시트 선택 완료
    case conflictResolved
}

@MainActor
protocol ShortcutRecorderViewDelegate: AnyObject {
    /// 녹화 시작 — `.recording` 사유를 넣는다.
    func recorderDidBeginRecording(_ recorder: ShortcutRecorderView)
    /// 녹화 종료 — `.recording` 사유를 뺀다. 어떤 경로로 끝나도 정확히 1회 불린다.
    func recorderDidEndRecording(_ recorder: ShortcutRecorderView, reason: ShortcutRecordingEndReason)
    /// 확정된 조합. 받는 쪽이 엔진 결과에 따라 `endRecording` 또는 겹침 시트를 띄운다.
    func recorder(_ recorder: ShortcutRecorderView, didCommit combo: KeyCombo)
    func recorderDidRequestClear(_ recorder: ShortcutRecorderView)
    func recorderDidRejectNoModifier(_ recorder: ShortcutRecorderView)
    /// 겹침 시트가 열린 채 앱이 비활성화됨 — 시트를 [취소]로 닫아야 한다.
    func recorderNeedsConflictDismissal(_ recorder: ShortcutRecorderView)
}

/// 단축키 녹화 칸. 클릭하면 녹화를 시작하고, 키 입력은 `ShortcutRecordingInterpreter`로 판정한다.
@MainActor
final class ShortcutRecorderView: NSView {
    let action: WindowAction
    weak var delegate: ShortcutRecorderViewDelegate?

    var combo: KeyCombo? {
        didSet { updateAppearance() }
    }

    /// 등록 실패 경고 표시.
    var hasWarning = false {
        didSet { updateAppearance() }
    }

    private(set) var isRecording = false
    /// 겹침 시트가 열린 동안 true. 이때는 첫 응답자 상실·클릭을 녹화 종료로 보지 않는다.
    var isAwaitingConflictDecision = false

    private var previewModifiers: RecordingModifiers = []
    private var clickMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?
    private let clearButton = NSButton()

    init(action: WindowAction) {
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: 140, height: 24))
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(SettingsFormLayout.title(for: action))

        clearButton.bezelStyle = .inline
        clearButton.isBordered = false
        clearButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: L10n.tr("Clear"))
        clearButton.imagePosition = .imageOnly
        clearButton.contentTintColor = .tertiaryLabelColor
        clearButton.refusesFirstResponder = true
        clearButton.target = self
        clearButton.action = #selector(clearClicked(_:))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clearButton)
        NSLayoutConstraint.activate([
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 16),
            clearButton.heightAnchor.constraint(equalToConstant: 16),
        ])
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 140, height: 24)
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - 녹화 시작·종료

    override func mouseDown(with event: NSEvent) {
        guard !isRecording else { return }
        guard window?.makeFirstResponder(self) == true else { return }
        beginRecording()
    }

    private func beginRecording() {
        isRecording = true
        previewModifiers = []
        delegate?.recorderDidBeginRecording(self)

        // 체크박스 등 첫 응답자가 되지 않는 컨트롤 클릭도 "다른 컨트롤 클릭"으로 본다(우리 앱 안의 로컬 이벤트만, 이벤트는 그대로 전달).
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleClickWhileRecording(event)
            return event
        }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applicationDidResignActive() }
        }
        updateAppearance()
    }

    /// 녹화 종료의 유일한 경로. 이미 녹화 중이 아니면 아무것도 하지 않는다(중복 호출 안전).
    func endRecording(reason: ShortcutRecordingEndReason) {
        guard isRecording else { return }
        isRecording = false
        isAwaitingConflictDecision = false
        previewModifiers = []
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        clickMonitor = nil
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
        }
        resignActiveObserver = nil

        delegate?.recorderDidEndRecording(self, reason: reason)
        if reason != .lostFocus, window?.firstResponder === self {
            window?.makeFirstResponder(nil)
        }
        updateAppearance()
    }

    override func resignFirstResponder() -> Bool {
        if isRecording, !isAwaitingConflictDecision {
            endRecording(reason: .lostFocus)
        }
        return true
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            endRecording(reason: .windowClosed)
        }
        super.viewWillMove(toWindow: newWindow)
    }

    private func handleClickWhileRecording(_ event: NSEvent) {
        guard isRecording, !isAwaitingConflictDecision else { return }
        if event.window === window {
            let point = convert(event.locationInWindow, from: nil)
            if bounds.contains(point) { return }
        }
        endRecording(reason: .lostFocus)
    }

    private func applicationDidResignActive() {
        guard isRecording else { return }
        if isAwaitingConflictDecision {
            delegate?.recorderNeedsConflictDismissal(self)
        }
        endRecording(reason: .appDeactivated)
    }

    // MARK: - 키 입력

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        handleKey(event)
    }

    /// 녹화 중에는 ⌘W·⌘Q 같은 메뉴 단축키가 실행되지 않도록 여기서 가로챈다.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        handleKey(event)
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }
        previewModifiers = Self.recordingModifiers(event.modifierFlags)
        updateAppearance()
    }

    private func handleKey(_ event: NSEvent) {
        guard !isAwaitingConflictDecision else { return }
        switch ShortcutRecordingInterpreter.interpret(keyCode: event.keyCode, modifiers: Self.recordingModifiers(event.modifierFlags)) {
        case .ignore:
            break
        case .cancel:
            endRecording(reason: .cancelled)
        case .clear:
            delegate?.recorderDidRequestClear(self)
            endRecording(reason: .cleared)
        case .rejectNoModifier:
            NSSound.beep()
            delegate?.recorderDidRejectNoModifier(self)
        case let .commit(combo):
            delegate?.recorder(self, didCommit: combo)
        }
    }

    @objc private func clearClicked(_ sender: NSButton) {
        delegate?.recorderDidRequestClear(self)
        endRecording(reason: .cleared)
    }

    static func recordingModifiers(_ flags: NSEvent.ModifierFlags) -> RecordingModifiers {
        var result: RecordingModifiers = []
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.function) { result.insert(.function) }
        if flags.contains(.capsLock) { result.insert(.capsLock) }
        return result
    }

    // MARK: - 그리기

    private var displayText: String {
        if isRecording {
            let symbols = Self.modifierSymbols(previewModifiers)
            return symbols.isEmpty ? SettingsFormLayout.recordingPrompt : symbols + "…"
        }
        return combo?.displayString ?? SettingsFormLayout.emptyShortcutPlaceholder
    }

    private static func modifierSymbols(_ modifiers: RecordingModifiers) -> String {
        let ordered: [(RecordingModifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return ordered.filter { modifiers.contains($0.0) }.map(\.1).joined()
    }

    private func updateAppearance() {
        clearButton.isHidden = combo == nil || isRecording
        toolTip = hasWarning ? SettingsFormLayout.registrationFailureMessage : nil
        setAccessibilityValue(displayText)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        NSColor.controlBackgroundColor.setFill()
        path.fill()

        let borderColor: NSColor
        if isRecording {
            borderColor = .controlAccentColor
        } else if hasWarning {
            borderColor = .systemOrange
        } else {
            borderColor = .separatorColor
        }
        borderColor.setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let textColor: NSColor = (combo == nil && !isRecording) ? .secondaryLabelColor : .labelColor
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
        ]
        let text = (hasWarning && !isRecording ? "⚠ " : "") + displayText
        let size = text.size(withAttributes: attributes)
        let textRect = NSRect(x: rect.minX + 4, y: rect.midY - size.height / 2, width: rect.width - 24, height: size.height)
        text.draw(in: textRect, withAttributes: attributes)
    }
}
