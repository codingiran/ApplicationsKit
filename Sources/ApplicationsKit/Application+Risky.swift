//
//  Application+Risky.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/4/2.
//

import Foundation

#if os(macOS)

// MARK: - Risky Detection

public extension Application {
    var isCodeSignedValid: Bool {
        Self.checkCodeSign(at: path)
    }

    var isRisky: Bool {
        return !isCodeSignedValid
    }
}

// MARK: - Check CodeSign

fileprivate extension Application {
    static func checkCodeSign(at url: URL) -> Bool {
        let pipe = Pipe()
        let task = codeSignTask(for: url.path, pipe: pipe)
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            guard task.terminationStatus == 0,
                  let output, !output.isEmpty
            else {
                return false
            }
            /*
             Executable=/Applications/Visual Studio Code.app/Contents/MacOS/Electron
             Identifier=com.microsoft.VSCode
             Format=app bundle with Mach-O universal (x86_64 arm64)
             CodeDirectory v=20500 size=768 flags=0x10000(runtime) hashes=13+7 location=embedded
             Hash type=sha256 size=32
             CandidateCDHash sha256=a2b6c444c428c0c2858a8d577ef81195aa7a67ca
             CandidateCDHashFull sha256=a2b6c444c428c0c2858a8d577ef81195aa7a67ca7ddbe4eda2911628fa3d3f4a
             Hash choices=sha256
             CMSDigest=a2b6c444c428c0c2858a8d577ef81195aa7a67ca7ddbe4eda2911628fa3d3f4a
             CMSDigestType=2
             CDHash=a2b6c444c428c0c2858a8d577ef81195aa7a67ca
             Signature size=9013
             Authority=Developer ID Application: Microsoft Corporation (UBF8T346G9)
             Authority=Developer ID Certification Authority
             Authority=Apple Root CA
             Timestamp=Mar 12, 2025 at 22:31:07
             Notarization Ticket=stapled
             Info.plist entries=36
             TeamIdentifier=UBF8T346G9
             Runtime Version=15.1.0
             Sealed Resources version=2 rules=13 files=2157
             Internal requirements count=1 size=180
             */
            let components = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let authorities = components.filter { $0.hasPrefix("Authority=") }.map { $0.dropFirst(10) }
            if authorities.isEmpty {
                // No authority
                return false
            }
            let constainsRisk = authorities.contains {
                $0.contains("TNT") || $0.contains("HCiSO")
            }
            if constainsRisk {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    /// codesign -dvvv /Applications/xxxx.app/ to check codesign
    static func codeSignTask(for path: String, pipe: Pipe) -> Process {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-dvvv", path]

        // Use Pipe to capture the output
        task.standardOutput = pipe
        task.standardError = pipe // Capture stderr in case there are errors
        return task
    }
}

#endif
