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
        case appNameNotFound(URL)
        case appBundleIdentifierNotFound(URL)
        case appVersionNotFound(URL)
        case appLogicalSizeNotFound(URL)
        case appPhysicalSizeNotFound(URL)

        var errorDescription: String? {
            switch self {
            case let .noAppFilesFound(url):
                return "No .app files found in the directory: \(url)"
            case let .appContentsReadingFailed(error, url):
                return "Error reading app contents at directory: \(url) failed: \(error.localizedDescription)"
            case let .appBundleNotFound(url):
                return "App bundle not found at directory: \(url)"
            case let .appNameNotFound(url):
                return "App name not found at directory: \(url)"
            case let .appBundleIdentifierNotFound(url):
                return "App bundle identifier not found at directory: \(url)"
            case let .appVersionNotFound(url):
                return "App version not found at directory: \(url)"
            case let .appLogicalSizeNotFound(url):
                return "App logical size not found at directory: \(url)"
            case let .appPhysicalSizeNotFound(url):
                return "App physical size not found at directory: \(url)"
            }
        }
    }
}

#if os(macOS)

// MARK: - Fetch from Metadata

extension Application {
    static func getAppInfo(fromMetadata metadata: MDLSMetadata, at url: URL) throws -> Application {
        // Extract metadata attributes for known fields
        let appName = {
            // use displayName if available, otherwise use fsName
            if let displayName = metadata.displayName?.replacingOccurrences(of: ".app", with: "").capitalizingFirstLetter(),
               !displayName.isEmpty
            {
                return displayName
            }
            return metadata.fsName ?? url.lastPathComponent
        }()

        let bundleIdentifier = metadata.bundleIdentifier

        // Some apps don't have a version, so we use an empty string as a fallback
        // etc. Old version Electron apps
        let appVersion = metadata.version ?? ""

        // Some apps may not have valid size
        // etc. SF Symbols
        let bundleSize = metadata.logicalSize ?? metadata.physicalSize ?? 0

        guard !appName.isEmpty else {
            throw Application.FetcherError.appNameNotFound(url)
        }
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
            throw Application.FetcherError.appBundleIdentifierNotFound(url)
        }

        // Extract optional date fields
        let creationDate = metadata.fsCreationDate
        let contentChangeDate = metadata.fsContentChangeDate
        let lastUsedDate = metadata.lastUsedDate

        // Determine architecture type
        let arch = determineArchitecture(from: metadata)

        // Use similar helper functions as `AppInfoFetcher` for attributes not found in metadata
        let isWrapped = isDirectoryWrapped(path: url)
        let isWebApp = isWebApp(appPath: url)
        let isGlobal = !url.filePath.contains(NSHomeDirectory())

        // Copyright and App Store category are not available in metadata
        let copyright = metadata.copyright
        let appStoreCategory = metadata.appStoreCategory
        let appStoreCategoryType = metadata.appStoreCategoryType

        return Application(path: url,
                           bundleIdentifier: bundleIdentifier,
                           appName: appName,
                           appVersion: appVersion,
                           isWebApp: isWebApp,
                           isWrapped: isWrapped,
                           isGlobal: isGlobal,
                           isFromMetadata: true,
                           arch: arch,
                           bundleSize: bundleSize,
                           creationDate: creationDate,
                           contentChangeDate: contentChangeDate,
                           lastUsedDate: lastUsedDate,
                           copyright: copyright,
                           appStoreCategory: appStoreCategory,
                           appStoreCategoryType: appStoreCategoryType)
    }

    /// Determine the architecture type based on metadata
    static func determineArchitecture(from metadata: MDLSMetadata) -> Application.Arch {
        guard let architectures = metadata.executableArchitectures else {
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
                           lastUsedDate: nil,
                           copyright: nil,
                           appStoreCategory: nil,
                           appStoreCategoryType: nil)
    }
}

// MARK: - Detect Web App

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

#if os(macOS)

// MARK: Fetch Seller Name

public extension Application {
    func fetchSellerNameInCodeSign(_ codeSign: CodesignUtils.CodeSignInfo? = nil) -> String? {
        guard let codeSign = try? codeSign ?? self.codeSign() else {
            return nil
        }
        return codeSign.vendorInCodeSign
    }
}

// MARK: Fetch Seller Name from App Store

public extension Application {
    func fetchAppSellerNameFromAppStore() async -> String? {
        await fetchAppSellerNameFromAppStore(by: bundleIdentifier)
    }

    private func fetchAppSellerNameFromAppStore(by bundleId: String) async -> String? {
        let urlStr = "https://itunes.apple.com/lookup?bundleId=\(bundleId)"
        guard let url = URL(string: urlStr) else {
            return nil
        }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 5)
        let response = try? await URLSession.shared.data(for: request)
        guard let data = response?.0 else {
            return nil
        }
        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any],
              let results = dict["results"] as? [[String: Any]],
              let firstResult = results.first,
              let sellerName = firstResult["sellerName"] as? String,
              !sellerName.isEmpty
        else {
            return nil
        }
        return sellerName
    }
}

#endif
