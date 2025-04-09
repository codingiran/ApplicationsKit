//
//  Application+Fetch.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/1/20.
//

import Foundation

// MARK: - Fetch Error

extension Application {
    enum FetcherError: LocalizedError, Sendable {
        case noAppFilesFound(URL)
        case appContentsReadingFailed(Error, URL)
        case appBundleNotFound(URL)
        case appBundleIdentifierNotFound(URL)

        var errorDescription: String? {
            switch self {
            case .noAppFilesFound(let url):
                return "No .app files found in the directory: \(url)"
            case .appContentsReadingFailed(let error, let url):
                return "Error reading app contents at directory: \(url) failed: \(error.localizedDescription)"
            case .appBundleNotFound(let url):
                return "App bundle not found at directory: \(url)"
            case .appBundleIdentifierNotFound(let url):
                return "App bundle identifier not found at directory: \(url)"
            }
        }
    }
}

#if os(macOS)

// MARK: - Fetch from Metadata

extension Application {
    static func getAppInfo(fromMetadata metadata: MDLSMetadata, at url: URL) throws -> Application {
        // Extract metadata attributes for known fields
        var displayName = metadata["kMDItemDisplayName"] as? String ?? ""
        displayName = displayName.replacingOccurrences(of: ".app", with: "").capitalizingFirstLetter()
        let fsName = metadata["kMDItemFSName"] as? String ?? url.lastPathComponent
        let appName = displayName.isEmpty ? fsName : displayName

        let bundleIdentifier = metadata["kMDItemCFBundleIdentifier"] as? String ?? ""
        let version = metadata["kMDItemVersion"] as? String ?? ""

        // Sizes
        let logicalSize = metadata["kMDItemLogicalSize"] as? Int64 ?? 0
        let physicalSize = metadata["kMDItemPhysicalSize"] as? Int64 ?? 0

        // Check if any of the critical fields are missing or invalid
        if appName.isEmpty || bundleIdentifier.isEmpty || version.isEmpty || logicalSize == 0 || physicalSize == 0 {
            // Fallback to the regular AppInfoFetcher for this app
            return try getAppInfo(at: url)
        }

        // Extract optional date fields
        let creationDate = metadata["kMDItemFSCreationDate"] as? Date
        let contentChangeDate = metadata["kMDItemFSContentChangeDate"] as? Date
        let lastUsedDate = metadata["kMDItemLastUsedDate"] as? Date

        // Determine architecture type
        let arch = determineArchitecture(from: metadata)

        // Use similar helper functions as `AppInfoFetcher` for attributes not found in metadata
        let isWrapped = isDirectoryWrapped(path: url)
        let isWebApp = isWebApp(appPath: url)
        let isGlobal = !url.filePath.contains(NSHomeDirectory())

        return Application(path: url,
                           bundleIdentifier: bundleIdentifier,
                           appName: appName,
                           appVersion: version,
                           isWebApp: isWebApp,
                           isWrapped: isWrapped,
                           isGlobal: isGlobal,
                           isFromMetadata: true,
                           arch: arch,
                           bundleSize: logicalSize,
                           creationDate: creationDate,
                           contentChangeDate: contentChangeDate,
                           lastUsedDate: lastUsedDate)
    }

    /// Determine the architecture type based on metadata
    static func determineArchitecture(from metadata: MDLSMetadata) -> Application.Arch {
        guard let architectures = metadata["kMDItemExecutableArchitectures"] as? [String] else {
            return .empty
        }

        // Check for ARM and Intel presence
        let containsArm = architectures.contains("arm64")
        let containsIntel = architectures.contains("x86_64")

        // Determine the Arch type based on available architectures
        if containsArm && containsIntel {
            return .universal
        } else if containsArm {
            return .arm
        } else if containsIntel {
            return .intel
        } else {
            return .empty
        }
    }
}

#endif

// MARK: - Fetch from App Bundle

extension Application {
    static func getAppInfo(at url: URL, wrapped: Bool = false) throws -> Application {
        if isDirectoryWrapped(path: url) {
            return try handleWrappedDirectory(at: url)
        } else {
            return try createAppInfoFromBundle(at: url, wrapped: wrapped)
        }
    }

    static func isDirectoryWrapped(path: URL) -> Bool {
        let wrapperURL = path.appendingPath("Wrapper")
        return FileManager.default.fileExists(at: wrapperURL)
    }

    static func handleWrappedDirectory(at url: URL) throws -> Application {
        let wrapperURL = url.appendingPath("Wrapper")
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: wrapperURL, includingPropertiesForKeys: nil)
            guard let firstAppFile = contents.first(where: { $0.pathExtension == "app" }) else {
                throw Application.FetcherError.noAppFilesFound(wrapperURL)
            }
            let fullPath = wrapperURL.appendingPath(firstAppFile.lastPathComponent)
            return try getAppInfo(at: fullPath, wrapped: true)
        } catch {
            throw Application.FetcherError.appContentsReadingFailed(error, wrapperURL)
        }
    }

    static func createAppInfoFromBundle(at url: URL, wrapped: Bool) throws -> Application {
        guard let bundle = Bundle(url: url) else {
            throw Application.FetcherError.appBundleNotFound(url)
        }
        guard let bundleIdentifier = bundle.bundleIdentifier else {
            throw Application.FetcherError.appBundleIdentifierNotFound(url)
        }

        let appName = wrapped ? url.deletingLastPathComponent().deletingLastPathComponent().deletingPathExtension().lastPathComponent.capitalizingFirstLetter() : url.localizedName().capitalizingFirstLetter()

        let appVersion = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String)?.isEmpty ?? true
            ? bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""
            : bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        let isWebApp = isWebApp(bundle: bundle)
        let isGlobal = !url.filePath.contains(NSHomeDirectory())

        return Application(path: url,
                           bundleIdentifier: bundleIdentifier,
                           appName: appName,
                           appVersion: appVersion,
                           isWebApp: isWebApp,
                           isWrapped: wrapped,
                           isGlobal: isGlobal,
                           isFromMetadata: false,
                           arch: .empty,
                           bundleSize: 0,
                           creationDate: nil,
                           contentChangeDate: nil,
                           lastUsedDate: nil)
    }
}

extension Application {
    /// Determines if the app is a web application by directly reading its `Info.plist` using the app path.
    static func isWebApp(appPath: URL) -> Bool {
        guard let bundle = Bundle(url: appPath) else { return false }
        return isWebApp(bundle: bundle)
    }

    /// Determines if the app is a web application based on its bundle.
    static func isWebApp(bundle: Bundle?) -> Bool {
        guard let infoDict = bundle?.infoDictionary else { return false }
        return (infoDict["LSTemplateApplication"] as? Bool ?? false) ||
            (infoDict["CFBundleExecutable"] as? String == "app_mode_loader")
    }
}
