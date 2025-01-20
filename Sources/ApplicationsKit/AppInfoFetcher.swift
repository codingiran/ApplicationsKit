//
//  AppInfoFetch.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/1/20.
//

import AppKit
import Foundation

public enum AppInfoFetcherError: LocalizedError {
    case noAppFilesFound(URL)
    case appContentsReadingFailed(Error, URL)
    case appBundleNotFound(URL)
    case appBundleIdentifierNotFound(URL)

    public var errorDescription: String? {
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

class AppInfoFetcher {
    static let fileManager = FileManager.default

    public static func getAppInfo(at url: URL, wrapped: Bool = false) throws -> Application {
        if isDirectoryWrapped(path: url) {
            return try handleWrappedDirectory(at: url)
        } else {
            return try createAppInfoFromBundle(at: url, wrapped: wrapped)
        }
    }

    public static func isDirectoryWrapped(path: URL) -> Bool {
        let wrapperURL = path.appendingPathComponent("Wrapper")
        return fileManager.fileExists(atPath: wrapperURL.path)
    }

    private static func handleWrappedDirectory(at url: URL) throws -> Application {
        let wrapperURL = url.appendingPathComponent("Wrapper")
        do {
            let contents = try fileManager.contentsOfDirectory(at: wrapperURL, includingPropertiesForKeys: nil)
            guard let firstAppFile = contents.first(where: { $0.pathExtension == "app" }) else {
                throw AppInfoFetcherError.noAppFilesFound(wrapperURL)
            }
            let fullPath = wrapperURL.appendingPathComponent(firstAppFile.lastPathComponent)
            return try getAppInfo(at: fullPath, wrapped: true)
        } catch {
            throw AppInfoFetcherError.appContentsReadingFailed(error, wrapperURL)
        }
    }

    private static func createAppInfoFromBundle(at url: URL, wrapped: Bool) throws -> Application {
        guard let bundle = Bundle(url: url) else {
            throw AppInfoFetcherError.appBundleNotFound(url)
        }
        guard let bundleIdentifier = bundle.bundleIdentifier else {
            throw AppInfoFetcherError.appBundleIdentifierNotFound(url)
        }

        let appName = wrapped ? url.deletingLastPathComponent().deletingLastPathComponent().deletingPathExtension().lastPathComponent.capitalizingFirstLetter() : url.localizedName().capitalizingFirstLetter()

        let appVersion = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String)?.isEmpty ?? true
            ? bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""
            : bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        let isWebApp = AppInfoUtils.isWebApp(bundle: bundle)
        let isSystem = !url.path.contains(NSHomeDirectory())

        return Application(path: url,
                           bundleIdentifier: bundleIdentifier,
                           appName: appName,
                           appVersion: appVersion,
                           isWebApp: isWebApp,
                           isWrapped: wrapped,
                           isSystem: isSystem,
                           isFromMetadata: false,
                           arch: .empty,
                           bundleSize: 0,
                           creationDate: nil,
                           contentChangeDate: nil,
                           lastUsedDate: nil)
    }
}

// Metadata-based AppInfo Fetcher Class
class MetadataAppInfoFetcher {
    static func getAppInfo(fromMetadata metadata: [String: Any], at url: URL) throws -> Application {
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
            return try AppInfoFetcher.getAppInfo(at: url)
        }

        // Extract optional date fields
        let creationDate = metadata["kMDItemFSCreationDate"] as? Date
        let contentChangeDate = metadata["kMDItemFSContentChangeDate"] as? Date
        let lastUsedDate = metadata["kMDItemLastUsedDate"] as? Date

        // Determine architecture type
        let arch = determineArchitecture(from: metadata)

        // Use similar helper functions as `AppInfoFetcher` for attributes not found in metadata
        let isWrapped = AppInfoFetcher.isDirectoryWrapped(path: url)
        let isWebApp = AppInfoUtils.isWebApp(appPath: url)
        let isSystem = !url.path.contains(NSHomeDirectory())

        return Application(path: url,
                           bundleIdentifier: bundleIdentifier,
                           appName: appName,
                           appVersion: version,
                           isWebApp: isWebApp,
                           isWrapped: isWrapped,
                           isSystem: isSystem,
                           isFromMetadata: true,
                           arch: arch,
                           bundleSize: logicalSize,
                           creationDate: creationDate,
                           contentChangeDate: contentChangeDate,
                           lastUsedDate: lastUsedDate)
    }

    /// Determine the architecture type based on metadata
    private static func determineArchitecture(from metadata: [String: Any]) -> Application.Arch {
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

class AppInfoUtils {
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

    /// Fetch App Icon URL
    static func fetchAppIconPath(for url: URL, wrapped: Bool, metaData: Bool) -> URL {
        let iconURL = wrapped ? (metaData ? url : url.deletingLastPathComponent().deletingLastPathComponent()) : url
        return iconURL
    }

    /// Fetch App Icon Image
    static func fetchAppIcon(for url: URL, wrapped: Bool, metaData: Bool, preferedSize: NSSize = .init(width: 50, height: 50)) -> NSImage? {
        let path = fetchAppIconPath(for: url, wrapped: wrapped, metaData: metaData)
        return NSWorkspace.shared.icon(forFile: path.path).convertICNSToPNG(size: preferedSize)
    }
}
