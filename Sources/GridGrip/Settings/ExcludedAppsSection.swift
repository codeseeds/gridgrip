import AppKit
import UniformTypeIdentifiers
import WindowCore

/// "이 앱에서는 끄기" 섹션: 제외 앱 표(아이콘·앱 이름·번들 ID) + [+]/[−].
/// 변경은 `ActivationPolicy.update` 한 경로로만 한다(저장·엔진 사유는 관찰자가 처리).
@MainActor
final class ExcludedAppsSection: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private enum Column {
        static let icon = NSUserInterfaceItemIdentifier("icon")
        static let name = NSUserInterfaceItemIdentifier("name")
        static let bundleID = NSUserInterfaceItemIdentifier("bundleID")
    }

    private let activation: ActivationPolicy
    private let tableView = NSTableView()
    private let removeButton = NSButton()
    private let messageLabel = SettingsLabels.warning()
    private var bundleIDs: [String] = []
    /// 시트를 붙일 창.
    weak var hostWindow: NSWindow?

    private(set) lazy var view: NSView = makeView()

    init(activation: ActivationPolicy) {
        self.activation = activation
    }

    func refresh() {
        bundleIDs = activation.excludedBundleIDs
        tableView.reloadData()
        updateRemoveButton()
    }

    private func makeView() -> NSView {
        let columns: [(NSUserInterfaceItemIdentifier, String, CGFloat)] = [
            (Column.icon, "", 24), (Column.name, L10n.tr("App Name"), 180), (Column.bundleID, L10n.tr("Bundle ID"), 280),
        ]
        for (id, title, width) in columns {
            let column = NSTableColumn(identifier: id)
            column.title = title
            column.width = width
            tableView.addTableColumn(column)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 22
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 110).isActive = true

        let addButton = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: L10n.tr("Add App"))!,
                                 target: self, action: #selector(addClicked(_:)))
        removeButton.image = NSImage(systemSymbolName: "minus", accessibilityDescription: L10n.tr("Remove Selected App"))
        removeButton.bezelStyle = addButton.bezelStyle
        removeButton.target = self
        removeButton.action = #selector(removeClicked(_:))
        let buttons = NSStackView(views: [addButton, removeButton])
        buttons.spacing = 4

        let stack = NSStackView(views: [scroll, buttons, messageLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        // 표는 섹션 폭(= 구분선 폭)을 꽉 채운다. 섹션 폭은 설정 창이 정한다.
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.spacing = 6
        refresh()
        return stack
    }

    // MARK: - 추가·삭제

    @objc private func addClicked(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self, weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            self?.add(appAt: url)
        }
        if let hostWindow {
            panel.beginSheetModal(for: hostWindow, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    private func add(appAt url: URL) {
        let bundleID = Bundle(url: url)?.bundleIdentifier ?? ""
        var settings = GeneralSettings(policy: activation)
        switch settings.addExcluded(bundleID, selfBundleID: AppIdentity.bundleIdentifier) {
        case .added:
            messageLabel.stringValue = ""
            activation.update(excludedBundleIDs: settings.excludedBundleIDs)
        case .duplicate:
            messageLabel.stringValue = L10n.tr("This app is already in the list")
        case .rejectedSelf:
            messageLabel.stringValue = L10n.tr("%@ itself can't be added", AppIdentity.displayName)
        case .rejectedEmpty:
            messageLabel.stringValue = L10n.tr("Couldn't read this app's bundle ID")
        }
    }

    @objc private func removeClicked(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard bundleIDs.indices.contains(row) else { return }
        var settings = GeneralSettings(policy: activation)
        settings.removeExcluded(bundleIDs[row])
        messageLabel.stringValue = ""
        activation.update(excludedBundleIDs: settings.excludedBundleIDs)
    }

    private func updateRemoveButton() {
        removeButton.isEnabled = bundleIDs.indices.contains(tableView.selectedRow)
    }

    // MARK: - 표

    func numberOfRows(in tableView: NSTableView) -> Int {
        bundleIDs.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButton()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn?.identifier, bundleIDs.indices.contains(row) else { return nil }
        let bundleID = bundleIDs[row]
        // 설치돼 있지 않으면 일반 앱 아이콘 + 이름 칸에 번들 ID(제거된 앱도 식별·삭제할 수 있게).
        let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        switch column {
        case Column.icon:
            let icon = appURL.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .applicationBundle)
            icon.size = NSSize(width: 18, height: 18)
            return NSImageView(image: icon)
        case Column.name:
            return NSTextField(labelWithString: appURL.map(Self.displayName(of:)) ?? bundleID)
        default:
            let label = NSTextField(labelWithString: bundleID)
            label.textColor = .secondaryLabelColor
            return label
        }
    }

    private static func displayName(of url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
