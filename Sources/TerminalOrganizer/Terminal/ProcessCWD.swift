import CWDProbe
import Darwin
import Foundation
import TOSupport

enum ProcessCWD {
    static func parent(of pid: Int32) -> Int32? {
        guard pid > 1 else { return nil }
        var parent: pid_t = 0
        let result = parent_probe_pid(pid, &parent)
        guard result == 0, parent > 0, parent != pid else { return nil }
        return parent
    }

    static func path(for pid: Int32) -> String? {
        guard pid > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let result = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return -1 }
            return cwd_probe_pid(pid, base, Int32(ptr.count))
        }
        guard result == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let raw = String(decoding: bytes, as: UTF8.self)
        guard !raw.isEmpty else { return nil }
        return PathMatch.resolved(raw)
    }

    static func name(of pid: Int32) -> String? {
        guard pid > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: 64)
        let result = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return -1 }
            return name_probe_pid(pid, base, Int32(ptr.count))
        }
        guard result == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let raw = String(decoding: bytes, as: UTF8.self)
        return raw.isEmpty ? nil : raw
    }

    static func children(of pid: Int32) -> [Int32] {
        guard pid > 0 else { return [] }
        var buffer = [pid_t](repeating: 0, count: 64)
        var count: Int32 = 0
        let result = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return -1 }
            return child_probe_pids(pid, base, Int32(ptr.count), &count)
        }
        guard result == 0, count > 0 else { return [] }
        return Array(buffer.prefix(Int(count)))
    }

    static func grokChild(of shellPid: Int32) -> Int32? {
        if name(of: shellPid) == "grok" { return shellPid }
        return children(of: shellPid).first { name(of: $0) == "grok" }
    }

    static func grokSessionOpenPath(of pid: Int32) -> String? {
        guard pid > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let result = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return -1 }
            return grok_session_path_probe_pid(pid, base, Int32(ptr.count))
        }
        guard result == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let raw = String(decoding: bytes, as: UTF8.self)
        return raw.isEmpty ? nil : raw
    }

    static func parseOSC7(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if let url = URL(string: value), url.isFileURL {
            let path = url.path
            return path.isEmpty ? nil : URL(fileURLWithPath: path).standardizedFileURL.path
        }
        if value.hasPrefix("/") {
            return URL(fileURLWithPath: value).standardizedFileURL.path
        }
        return nil
    }

    static func standardized(_ path: String) -> String {
        PathMatch.resolved(path)
    }

    static func resolved(_ path: String) -> String {
        PathMatch.resolved(path)
    }

    static func matchesSession(_ sessionCwd: String, eventCwd: String) -> Bool {
        PathMatch.matchesSession(sessionCwd, eventCwd: eventCwd)
    }
}

enum DefaultShell {
    static var path: String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"],
           FileManager.default.isExecutableFile(atPath: shell) {
            return shell
        }
        return "/bin/zsh"
    }

    static var loginName: String {
        "-" + URL(fileURLWithPath: path).lastPathComponent
    }
}
