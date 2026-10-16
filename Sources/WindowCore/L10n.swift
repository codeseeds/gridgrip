import Foundation

/// 화면 문구의 단일 통로. 키는 영어 원문이고, 번역은 앱 번들의 `<언어>.lproj/Localizable.strings`
/// (원본: Support/Localization)에서 찾는다. 번역이 없으면 영어 원문을 그대로 쓴다.
/// 키는 `L10n.tr("…")` 처럼 문자열 리터럴로 적는다 — 테스트가 소스에서 키를 모아 번역 표와 대조한다.
public enum L10n {
    /// 테스트에서 번역 표를 바꿔 끼울 때만 바꾼다.
    public static var bundle: Bundle = .main

    public static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return arguments.isEmpty ? format : String(format: format, locale: Locale.current, arguments: arguments)
    }
}
