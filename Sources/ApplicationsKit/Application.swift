//
//  Application.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/1/20.
//

import AppKit
import Foundation

/// A struct that represents an application.
public struct Application: Codable, Identifiable, Equatable, Hashable, Sendable {
    /// The unique identifier for the application.
    public var id = UUID().uuidString
    /// The path to the application.
    public let path: URL
    /// The bundle identifier for the application.
    public let bundleIdentifier: String
    /// The name of the application.
    public let appName: String
    /// The version of the application.
    public let appVersion: String
    /// Whether the application is a web app.
    public let isWebApp: Bool
    /// Whether the application is wrapped.
    public let isWrapped: Bool
    /// Whether the application is a global installed app.
    public let isGlobal: Bool
    /// Whether the application is from metadata.
    public let isFromMetadata: Bool
    /// The architecture of the application.
    public var arch: Application.Arch
    /// The bundle size of the application.
    public var bundleSize: Int64
    /// The creation date of the application.
    public let creationDate: Date?
    /// The content change date of the application.
    public let contentChangeDate: Date?
    /// The last used date of the application.
    public let lastUsedDate: Date?
}

#if os(macOS)

/// Gets the icon of the application.
public extension Application {
    /// The icon of the application.
    @available(macOS 10.15, *)
    func appIcon(size: NSSize = .init(width: 50, height: 50)) -> NSImage? {
        return Self.fetchAppIcon(for: path, wrapped: isWrapped, metaData: isFromMetadata, preferedSize: size)
    }
}
#endif

public extension Application {
    /// The architecture of the application.
    enum Arch: Codable, Sendable {
        /// The architecture is ARM.
        case arm
        /// The architecture is Intel.
        case intel
        /// The architecture is Universal.
        case universal
        /// The architecture is empty.
        case empty

        /// The type string of the architecture.
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
