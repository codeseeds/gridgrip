import Foundation

/// 번들 ID·이름·버전의 코드 내 단일 출처. 로깅 subsystem 등은 반드시 이 값을 쓴다.
public enum AppIdentity {
    public static let bundleIdentifier = "com.blackpet.GridGrip"
    public static let displayName = "GridGrip"
    public static let executableName = "GridGrip"
    public static let version = "0.2.0"
}
