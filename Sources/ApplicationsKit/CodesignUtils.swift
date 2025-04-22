//
//  CodesignUtils.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/4/18.
//

import Foundation

#if os(macOS)

struct CodesignUtils: Sendable {
    static func checkApplicationCodeSign(_ application: Application) throws -> CodesignUtils.CodeSignInfo {
        try checkCodeSign(at: application.path)
    }

    static func checkCodeSign(at url: URL) throws -> CodesignUtils.CodeSignInfo {
        guard FileManager.default.fileExists(at: url) else {
            throw CodeSignError.invalidPath
        }
        let pipe = Pipe()
        let task = codeSignTask(for: url.filePath, pipe: pipe)
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            guard task.terminationStatus == 0,
                  let output, !output.isEmpty
            else {
                throw CodeSignError.invalidOutput(output, task.terminationStatus)
            }
            return CodeSignInfo(output: output)
        } catch {
            throw CodeSignError.codeSignCommandFailed(error)
        }
    }

    /// codesign -dvvv /Applications/xxxx.app/ to check codesign
    static func codeSignTask(for path: String, pipe: Pipe) -> Process {
        let task = Process(launchPath: "/usr/bin/codesign", arguments: ["-dvvv", path])
        // Use Pipe to capture the output
        task.standardOutput = pipe
        task.standardError = pipe // Capture stderr in case there are errors
        return task
    }
}

extension CodesignUtils {
    enum CodeSignError: LocalizedError {
        case invalidPath
        case codeSignCommandFailed(Error)
        case invalidOutput(String?, Int32)

        var errorDescription: String? {
            switch self {
            case .invalidPath:
                return "The provided path is invalid or does not exist."
            case let .codeSignCommandFailed(error):
                return "Code sign command failed with error: \(error.localizedDescription)"
            case let .invalidOutput(output, status):
                return "Invalid output: \(output ?? "nil"), status: \(status)"
            }
        }
    }
}

extension CodesignUtils {
    /*
     Executable=/Applications/Visual Studio Code.app/Contents/MacOS/Electron
     Identifier=com.microsoft.VSCode
     Format=app bundle with Mach-O universal (x86_64 arm64)
     CodeDirectory v=20500 size=768 flags=0x10000(runtime) hashes=13+7 location=embedded
     Hash type=sha256 size=32
     CandidateCDHash sha256=b5db5462722e69e003b2d8d1cdc97a0688e8500f
     CandidateCDHashFull sha256=b5db5462722e69e003b2d8d1cdc97a0688e8500f950d5e9877ac8b2c37748f54
     Hash choices=sha256
     CMSDigest=b5db5462722e69e003b2d8d1cdc97a0688e8500f950d5e9877ac8b2c37748f54
     CMSDigestType=2
     CDHash=b5db5462722e69e003b2d8d1cdc97a0688e8500f
     Signature size=9013
     Authority=Developer ID Application: Microsoft Corporation (UBF8T346G9)
     Authority=Developer ID Certification Authority
     Authority=Apple Root CA
     Timestamp=Apr 16, 2025 at 08:32:46
     Notarization Ticket=stapled
     Info.plist entries=36
     TeamIdentifier=UBF8T346G9
     Runtime Version=15.1.0
     Sealed Resources version=2 rules=13 files=2184
     Internal requirements count=1 size=180
     */
    struct CodeSignInfo: Sendable {
        var executablePath: String?
        var identifier: String?
        var format: String?
        var codeDirectory: String?
        var timestamp: String?
        var authorities: [String]?
        var teamIdentifier: String?
        var notarizationTicket: String?
        var runtimeVersion: String?

        var isAppStore: Bool {
            guard let authorities = authorities else { return false }
            // Check if the app is signed by Apple
            guard Set(authorities) == ["Apple Mac OS Application Signing", "Apple Worldwide Developer Relations Certification Authority", "Apple Root CA"] else {
                return false
            }
            return true
        }

        init(output: String) {
            let lines = output.split(separator: "\n")
            for line in lines {
                let components = line.split(separator: "=").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard components.count == 2 else { continue }
                let key = components[0]
                let value = components[1]

                switch key {
                case "Executable":
                    executablePath = String(value)
                case "Identifier":
                    identifier = String(value)
                case "Format":
                    format = String(value)
                case "CodeDirectory":
                    codeDirectory = String(value)
                case "Timestamp":
                    timestamp = String(value)
                case "Authority":
                    if authorities == nil { authorities = [] }
                    authorities?.append(String(value))
                case "TeamIdentifier":
                    teamIdentifier = String(value)
                case "Notarization Ticket":
                    notarizationTicket = String(value)
                case "Runtime Version":
                    runtimeVersion = String(value)
                default:
                    break
                }
            }
        }
    }
}

#endif
