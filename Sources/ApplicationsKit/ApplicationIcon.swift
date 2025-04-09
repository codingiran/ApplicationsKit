//
//  ApplicationIcon.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/4/9.
//

import Foundation

#if os(macOS)

#if canImport(AppKit)

import AppKit

@available(macOS 10.15, *)
public actor ApplicationIcon: @unchecked Sendable {
    public static let shared = ApplicationIcon()

    private init() {}

    private let cache = NSCache<NSString, NSImage>()

    func icon(for application: Application, preferedSize: NSSize? = nil, usingCache cacheType: CacheType = .memoryAndDisk) -> NSImage? {
        switch cacheType {
        case .none:
            // ignore cache, fetch icon directly
            return fetchAppIcon(for: application, preferedSize: preferedSize)
        case .memory:
            // only use memory cache
            return memoryIconCache(for: application, preferedSize: preferedSize)
                ?? fetchAppIcon(for: application, preferedSize: preferedSize)
        case .disk:
            // only use disk cache
            return diskIconCache(for: application, preferedSize: preferedSize)
                ?? fetchAppIcon(for: application, preferedSize: preferedSize)
        case .memoryAndDisk:
            // use memory and disk cache
            return memoryIconCache(for: application, preferedSize: preferedSize)
                ?? diskIconCache(for: application, preferedSize: preferedSize)
                ?? fetchAppIcon(for: application, preferedSize: preferedSize)
        }
    }
}

// MARK: - Cache

private extension ApplicationIcon {
    func cacheIcon(_ icon: NSImage?, for application: Application, preferedSize: NSSize?, cacheType: CacheType = .memoryAndDisk) throws {
        guard let icon, cacheType.useCache else {
            return
        }
        if cacheType.useMemoryCache {
            cache.setObject(icon, forKey: application.path.filePath as NSString)
        }
        if cacheType.useDiskCache {
            try saveAppIcon(icon, for: application, preferedSize: preferedSize)
        }
    }

    func memoryIconCache(for application: Application, preferedSize: NSSize?) -> NSImage? {
        let appPath = application.path.filePath
        guard let cachedIcon = cache.object(forKey: appPath as NSString) else {
            return nil
        }
        if let preferedSize, preferedSize != cachedIcon.size {
            cachedIcon.size = preferedSize
        }
        return cachedIcon
    }

    func diskIconCache(for application: Application, preferedSize: NSSize?) -> NSImage? {
        guard let cachedIcon = loadImageFromDisk(for: application) else {
            return nil
        }
        if let preferedSize, preferedSize != cachedIcon.size {
            cachedIcon.size = preferedSize
        }
        return cachedIcon
    }
}

// MARK: - File Handle

private extension ApplicationIcon {
    /// Fetch App Icon Image
    /// - Parameters:
    ///   - application: The Application need to fetch
    ///   - preferedSize: Specify prefered size
    /// - Returns: The App Icon
    func fetchAppIcon(for application: Application, preferedSize: NSSize? = nil, persistent: Bool = true) -> NSImage {
        let path = fetchAppIconPath(for: application.path, wrapped: application.isWrapped, metaData: application.isFromMetadata)
        let icon = NSWorkspace.shared.icon(forFile: path.filePath)
        if let preferedSize, preferedSize != icon.size {
            icon.size = preferedSize
        }
        if persistent {
            try? cacheIcon(icon, for: application, preferedSize: preferedSize)
        }
        return icon
    }

    /// Save App Icon to File
    /// - Parameters:
    ///   - application: The Application need to fetch
    ///   - preferedSize: Specify prefered size
    func saveAppIcon(_ icon: NSImage, for application: Application, preferedSize: NSSize? = nil) throws {
        guard let pngData = icon.convertICNSToPNGData(size: preferedSize) else {
            throw ApplicationIcon.Error.convertPNGDataFailed
        }
        do {
            try pngData.write(to: cacheURL(of: application))
        } catch {
            throw ApplicationIcon.Error.writeToFileFailed(error)
        }
    }

    /// Fetch App Icon URL
    func fetchAppIconPath(for url: URL, wrapped: Bool, metaData: Bool) -> URL {
        let iconURL = wrapped ? (metaData ? url : url.deletingLastPathComponent().deletingLastPathComponent()) : url
        return iconURL
    }
}

private extension ApplicationIcon {
    func loadImageFromDisk(for application: Application) -> NSImage? {
        guard
            let applicationURL = try? cacheURL(of: application),
            FileManager.default.fileExists(atPath: applicationURL.filePath)
        else {
            return nil
        }
        let image = NSImage(contentsOf: applicationURL)
        return image
    }

    func cacheURL(of application: Application) throws -> URL {
        do {
            return try applicationCacheDirectory().appendingPath("\(application.bundleIdentifier).png")
        } catch {
            throw ApplicationIcon.Error.applicationCacheURLInvalid(error)
        }
    }

    func applicationCacheDirectory() throws -> URL {
        let url = try FileManager.default.url(for: .cachesDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)
            .appendingPath("com.codingiran.applicationsKit")
            .appendingPath("ApplicationIconCache")
        if !FileManager.default.fileExists(at: url) {
            try FileManager.default.createDirectory(at: url,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        }
        return url
    }
}

public extension ApplicationIcon {
    enum CacheType: Sendable {
        case none
        case memory
        case disk
        case memoryAndDisk

        public var useCache: Bool {
            switch self {
            case .memory, .disk, .memoryAndDisk:
                return true
            case .none:
                return false
            }
        }

        public var useDiskCache: Bool {
            switch self {
            case .disk, .memoryAndDisk:
                return true
            default:
                return false
            }
        }

        public var useMemoryCache: Bool {
            switch self {
            case .memory, .memoryAndDisk:
                return true
            default:
                return false
            }
        }
    }
}

public extension ApplicationIcon {
    enum Error: LocalizedError, Sendable {
        case convertPNGDataFailed
        case writeToFileFailed(Swift.Error)
        case applicationCacheURLInvalid(Swift.Error)

        public var errorDescription: String? {
            switch self {
            case .convertPNGDataFailed:
                return "Convert PNG Data Failed"
            case .writeToFileFailed(let error):
                return "Write to File Failed: \(error.localizedDescription)"
            case .applicationCacheURLInvalid(let error):
                return "Application Cache URL Invalid: \(error.localizedDescription)"
            }
        }
    }
}

#endif

#endif
