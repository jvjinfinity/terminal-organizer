import Foundation

enum AppVersion {
    static var display: String {
        display(
            short: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        )
    }

    static func display(short: String, build: String) -> String {
        let short = short.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = build.trimmingCharacters(in: .whitespacesAndNewlines)
        if short.isEmpty { return build.isEmpty ? "0" : build }
        if build.isEmpty { return short }
        if short == build || short.hasSuffix(".\(build)") { return short }
        return "\(short).\(build)"
    }
}
