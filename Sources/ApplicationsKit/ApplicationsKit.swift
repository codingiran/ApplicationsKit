//
//  ApplicationsKit.swift
//  ApplicationsKit
//
//  Created by iran.qiu on 2025/01/20.
//

import Foundation

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.9.0)
#error("ApplicationsKit doesn't support Swift versions below 5.9.0")
#endif

/// Current ApplicationsKit version 0.0.. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
public let version = "0.0.1"

public enum ApplicationsKit {}

public extension ApplicationsKit {
    static var systemApplicationsDirectory: URL {
        if #available(macOS 13.0, *) {
            return URL.applicationDirectory
        } else {
            return URL(fileURLWithPath: "/Applications")
        }
    }

    static var userApplicationsDirectory: URL {
        if #available(macOS 13.0, *) {
            return URL.homeDirectory.appending(path: "Applications")
        } else {
            return URL(fileURLWithPath: "\(NSHomeDirectory())/Applications")
        }
    }

    static func systemApplications() -> [Application] {
        return applications(at: systemApplicationsDirectory)
    }

    static func userApplications() -> [Application] {
        return applications(at: userApplicationsDirectory)
    }

    static func applications(at directory: URL) -> [Application] {
        guard let appURLs = applicationURLs(at: directory) else {
            return []
        }
        return applications(of: appURLs)
    }

    static func applications(of appURLs: [URL]) -> [Application] {
        guard !appURLs.isEmpty else {
            return []
        }
        let combinedPaths = appURLs.map { $0.path }
        guard let metadataDictionary = try? MDLSUtils.getMDLSMetadataAsPlist(for: combinedPaths) else {
            return []
        }
        let apps: [Application] = appURLs.compactMap {
            let appPath = $0.path
            if let appMetadata = metadataDictionary[appPath] {
                // Use `MetadataAppInfoFetcher` first
                return try? MetadataAppInfoFetcher.getAppInfo(fromMetadata: appMetadata, at: $0)
            } else {
                return try? AppInfoFetcher.getAppInfo(at: $0)
                // Fallback to the regular AppInfoFetcher for this app
            }
        }
        return apps
    }

    static func applicationURLs(at directory: URL) -> [URL]? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(at: directory) else {
            return nil
        }
        let appURLs = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
        guard let appURLs, !appURLs.isEmpty else {
            return nil
        }
        var apps: [URL] = []
        for appURL in appURLs {
            if appURL.pathExtension == "app", !appURL.isRestricted, !appURL.isSymlink {
                apps.append(appURL)
            } else if appURL.hasDirectoryPath {
                if let recursiveApps = applicationURLs(at: appURL), !recursiveApps.isEmpty {
                    apps.append(contentsOf: recursiveApps)
                }
            }
        }
        return apps
    }
}
