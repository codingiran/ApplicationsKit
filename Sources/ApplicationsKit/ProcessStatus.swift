//
//  ProcessInfo.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/4/8.
//

import Foundation

#if os(macOS)

public struct ProcessStatus: Codable, Sendable {
    public let pid: Int32
    public let uid: Int16
    public let user: String
    public let name: String
    public let command: String

    public init(pid: Int32, uid: Int16, user: String, name: String, command: String) {
        self.pid = pid
        self.uid = uid
        self.user = user
        self.name = name
        self.command = command
    }

    public init(pid: Int32, uid: Int16, user: String, command: String) {
        let commandURL = URL(fileURLPath: command)
        let name = commandURL.lastPathComponent
        self.init(pid: pid, uid: uid, user: user, name: name, command: command)
    }

    fileprivate init?(line: String) {
        guard !line.isEmpty else {
            return nil
        }
        let components = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard components.count == 4,
              let pidStr = components[safeIndex: 0],
              let pid = Int32(pidStr),
              let uidStr = components[safeIndex: 1],
              let uid = Int16(uidStr),
              let user = components[safeIndex: 2],
              let command = components[safeIndex: 3]
        else {
            return nil
        }
        self.init(pid: pid, uid: uid, user: user, command: command)
    }
}

extension ProcessStatus: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public static func == (lhs: ProcessStatus, rhs: ProcessStatus) -> Bool {
        return
            lhs.pid == rhs.pid &&
            lhs.uid == rhs.uid &&
            lhs.user == rhs.user &&
            lhs.command == rhs.command
    }

    public var description: String {
        "ProcessStatus(pid: \(pid), uid: \(uid), user: \(user), name: \(name), command: \(command))"
    }

    public var debugDescription: String { description }
}

public extension ProcessStatus {
    static func all() -> [ProcessStatus] {
        let process = Process(launchPath: "/bin/ps", arguments: ["-A", "-o", "pid=,uid=,user=,comm="])
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }
        return .init(ps: output)
    }
}

private extension Array where Element == ProcessStatus {
    init(ps output: String) {
        guard !output.isEmpty else {
            self = []
            return
        }
        let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self = lines.compactMap { ProcessStatus(line: $0) }
    }
}

#endif
