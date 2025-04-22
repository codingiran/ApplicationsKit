//
//  ProcessStatus.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/4/8.
//

import Foundation

#if os(macOS)

    public struct ProcessStatus {
        /// The process ID of the process.
        public let pid: Int32
        /// The process group ID of the process.
        public let pgid: Int32
        /// The user ID of the process owner.
        public let uid: UInt32
        /// The user name of the process owner.
        public let user: String
        /// The name of the process.
        public let name: String
        /// The command line used to launch the process.
        public let command: String
        /// The date when the process started.
        public let startDate: Date
        /// The elapsed time since the process started.
        public let elapsedTime: TimeInterval

        public init(pid: Int32,
                    pgid: Int32,
                    uid: UInt32,
                    user: String,
                    name: String,
                    command: String,
                    startDate: Date,
                    elapsedTime: TimeInterval)
        {
            self.pid = pid
            self.pgid = pgid
            self.uid = uid
            self.user = user
            self.name = name
            self.command = command
            self.startDate = startDate
            self.elapsedTime = elapsedTime
        }
    }

    public extension ProcessStatus {
        static func allProcess() -> [ProcessStatus] {
            let maxProcesses = 4096
            let pidSize = MemoryLayout<pid_t>.size
            let pids = UnsafeMutablePointer<pid_t>.allocate(capacity: maxProcesses)
            defer { pids.deallocate() }

            let numberOfPids = proc_listallpids(pids, Int32(maxProcesses * pidSize))
            if numberOfPids <= 0 {
                return []
            }

            var processes = [ProcessStatus]()
            let now = Date()
            for i in 0 ..< numberOfPids {
                let pid = pids[Int(i)]
                let pgid = getpgid(pid)

                var info = proc_taskallinfo()
                let size = MemoryLayout<proc_taskallinfo>.stride

                let ret = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, Int32(size))
                if ret != size {
                    continue
                }

                let uid = info.pbsd.pbi_uid
                let startSec = info.pbsd.pbi_start_tvsec
                let launchDate = Date(timeIntervalSince1970: TimeInterval(startSec))
                let runningTime = now.timeIntervalSince(launchDate)

                let name = withUnsafePointer(to: info.pbsd.pbi_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXLOGNAME)) {
                        String(cString: $0)
                    }
                }
                let executablePath = {
                    var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
                    let result = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
                    guard result > 0, let path = String(utf8String: pathBuffer), !path.isEmpty else {
                        return ""
                    }
                    return path
                }()
                let user = {
                    guard let pw = getpwuid(uid), let nameCStr = pw.pointee.pw_name else {
                        return ""
                    }
                    return String(cString: nameCStr)
                }()
                let process = ProcessStatus(pid: pid, pgid: pgid, uid: uid, user: user, name: name, command: executablePath, startDate: launchDate, elapsedTime: runningTime)
                processes.append(process)
            }
            return processes
        }
    }

    extension ProcessStatus: Codable, Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        public static func == (lhs: ProcessStatus, rhs: ProcessStatus) -> Bool {
            return
                lhs.pid == rhs.pid &&
                lhs.pgid == rhs.pgid &&
                lhs.uid == rhs.uid &&
                lhs.user == rhs.user &&
                lhs.name == rhs.name &&
                lhs.command == rhs.command &&
                lhs.startDate == rhs.startDate &&
                lhs.elapsedTime == rhs.elapsedTime
        }

        public var description: String {
            "ProcessStatus(pid: \(pid), pgid: \(pgid), uid: \(uid), user: \(user), name: \(name), command: \(command), startDate: \(startDate), elapsedTime: \(elapsedTime))"
        }

        public var debugDescription: String { description }
    }

    private extension ProcessStatus {
        static let PROC_PIDPATHINFO_MAXSIZE = 4 * UInt32(MAXPATHLEN)
    }

    private extension pid_t {
        func ps(keyword: String) -> String? {
            let process = Process(launchPath: "/bin/ps", arguments: ["-p", "\(self)", "-o", "\(keyword)="])
            let pipe = Pipe()
            process.standardOutput = pipe
            do {
                try process.run()
            } catch {
                return nil
            }
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            else {
                return nil
            }
            return output
        }

        var psComm: String? {
            ps(keyword: "comm")
        }

        var psUser: String? {
            ps(keyword: "user")
        }
    }

#endif
