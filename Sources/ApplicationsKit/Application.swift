//
//  Application.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/1/20.
//

import AppKit
import Foundation

public struct Application: Codable, Identifiable, Equatable, Hashable {
    public var id = UUID().uuidString
    public let path: URL
    public let bundleIdentifier: String
    public let appName: String
    public let appVersion: String
    public let isWebApp: Bool
    public let isWrapped: Bool
    public let isSystem: Bool
    public let isFromMetadata: Bool
    public var arch: Application.Arch
    public var bundleSize: Int64
    public let creationDate: Date?
    public let contentChangeDate: Date?
    public let lastUsedDate: Date?

    public var metadataDictionary: [String: Any] {
        get throws {
            return try MDLSUtils.getMDLSMetadataAsPlist(for: path.path)?.values as? [String: Any] ?? [:]
        }
    }

    public func appIcon(size: NSSize = .init(width: 50, height: 50)) -> NSImage? {
        return AppInfoUtils.fetchAppIcon(for: path, wrapped: isWrapped, metaData: isFromMetadata, preferedSize: size)
    }
}

public extension Application {
    enum Arch: Codable {
        case arm
        case intel
        case universal
        case empty

        public var type: String {
            switch self {
            case .arm:
                return "arm"
            case .intel:
                return "intel"
            case .universal:
                return "universal"
            case .empty:
                return ""
            }
        }
    }
}
