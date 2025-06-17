//
//  ApplicationsKit.swift
//  ApplicationsKit
//
//  Created by iran.qiu on 2025/01/20.
//

import Foundation

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.10)
    #error("ApplicationsKit doesn't support Swift versions below 5.10")
#endif

/// The `ApplicationsKit` provides a set of static methods for working with applications on macOS.
public enum ApplicationsKit: Sendable {
    /// Current ApplicationsKit version 0.0.4. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
    public static let version = "0.0.4"
}

public extension ApplicationsKit {
    /// The system applications directory.
    static var systemApplicationsDirectory: URL {
        do {
            return try FileManager.default.url(for: .applicationDirectory, in: .localDomainMask, appropriateFor: nil, create: false)
        } catch {
            if #available(macOS 13.0, macCatalyst 16.0, *) {
                return URL.applicationDirectory
            } else {
                return URL(fileURLWithPath: "/Applications")
            }
        }
    }

    /// The current user applications directory.
    static var userApplicationsDirectory: URL {
        do {
            return try FileManager.default.url(for: .applicationDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        } catch {
            if #available(macOS 13.0, macCatalyst 16.0, *) {
                return URL.homeDirectory.appending(path: "Applications")
            } else {
                return URL(fileURLWithPath: "\(NSHomeDirectory())/Applications")
            }
        }
    }

    /// The applications directory for the specified user.
    static func applicationsDirectoryForUser(_ userName: String) -> URL? {
        var homeDirectory: URL?
        if #available(macOS 13.0, macCatalyst 16.0, *) {
            homeDirectory = URL.homeDirectory(forUser: userName)
        } else {
            if let homeDirectoryPath = NSHomeDirectoryForUser(userName) {
                homeDirectory = URL(fileURLPath: homeDirectoryPath)
            }
        }
        guard let homeDirectory else {
            return nil
        }
        return homeDirectory.appendingPath("Applications")
    }

    /// The system applications.
    static func systemApplications() -> [Application] {
        return applications(at: systemApplicationsDirectory)
    }

    /// The current user applications.
    static func userApplications() -> [Application] {
        return applications(at: userApplicationsDirectory)
    }

    /// The applications for the specified user.
    static func applicationsForUser(_ userName: String) -> [Application] {
        guard let homeDirectory = applicationsDirectoryForUser(userName) else {
            return []
        }
        return applications(at: homeDirectory)
    }

    /// The applications at the specified directory.
    ///
    /// - Parameters:
    ///   - directory: The directory to search for applications.
    /// - Returns: The applications at the specified directory.
    static func applications(at directory: URL) -> [Application] {
        guard let appURLs = applicationURLs(at: directory) else {
            return []
        }
        return applications(of: appURLs)
    }

    /// The applications of the specified URLs.
    ///
    /// - Parameters:
    ///   - appURLs: The URLs of the applications.
    /// - Returns: The applications of the specified URLs.
    static func applications(of appURLs: [URL]) -> [Application] {
        guard !appURLs.isEmpty else {
            return []
        }
        return appURLs.compactMap { application(of: $0) }
    }

    static func application(of appURL: URL) -> Application? {
        guard FileManager.default.fileExists(at: appURL) else {
            return nil
        }
        #if os(macOS)
            guard let appMetadata = try? MDLSUtils.parseMDItemCreation(for: appURL.filePath),
                  let app = try? Application.getAppInfo(fromMetadata: appMetadata, at: appURL)
            else {
                // Fallback to fetch from App Bundle
                return try? Application.getAppInfo(at: appURL)
            }
            return app
        #else
            // macCatalyst does not support MDLS, fallback to fetch from App Bundle
            return try? Application.getAppInfo(at: appURL)
        #endif
    }

    /// The application URLs at the specified directory.
    ///
    /// - Parameters:
    ///   - directory: The directory to search for applications.
    /// - Returns: The application URLs at the specified directory.
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
