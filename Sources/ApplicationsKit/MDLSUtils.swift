//
//  MDLSUtils.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/1/20.
//

import Foundation

#if os(macOS)

    import CoreServices

    enum MDLSParseError: LocalizedError, Sendable {
        case parseFailed(String)

        var errorDescription: String? {
            switch self {
            case let .parseFailed(message):
                return message
            }
        }
    }

    enum MDLSUtils: Sendable {}

    // MARK: - Fetch Metadata using [MDItemCreate](https://developer.apple.com/documentation/coreservices/1426917-mditemcreate)

    extension MDLSUtils {
        /// Executes `MDItemCreate` with the given path and returns the metadata.
        static func parseMDItemCreation(for path: String) throws -> MDLSMetadata {
            guard let item = MDItemCreate(nil, path as CFString) else {
                throw MDLSParseError.parseFailed("Failed to create MDItem for path: \(path)")
            }
            return item.itemMetadata
        }

        /// Executes `MDItemCreate` with the given paths and returns the metadata.
        static func parseMDItemCreation(for paths: [String]) throws -> [String: MDLSMetadata]? {
            let result = try paths.reduce(into: [:]) {
                $0[$1] = try parseMDItemCreation(for: $1)
            }
            return result
        }
    }

    extension MDItem {
        var itemMetadata: MDLSMetadata {
            let itemMetadata = MDLSMetadataAttribute.allCases.reduce(into: [:]) {
                $0[$1.rawValue] = MDItemCopyAttribute(self, $1.rawValue as CFString)
            }
            return .init(attributes: itemMetadata)
        }
    }

    // MARK: - Fetch Metadata using mdls command

    extension MDLSUtils {
        /// Executes `mdls` with `-plist -` and `-nullMarker ""` options and returns metadata in a structured dictionary.
        static func getMDLSMetadataAsPlist(for path: String) throws -> [String: MDLSMetadata]? {
            guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
            return try parseMDLSMetadataAsPlist(for: [path])
        }

        /// Executes `mdls` with `-plist -` and `-nullMarker ""` options and returns metadata in a structured dictionary.
        static func getMDLSMetadataAsPlist(for paths: [String]) throws -> [String: MDLSMetadata]? {
            let paths = paths.filter { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }
            return try parseMDLSMetadataAsPlist(for: paths)
        }

        /// Executes `mdls` with `-plist -` and `-nullMarker ""` options and returns metadata in a structured dictionary.
        static func parseMDLSMetadataAsPlist(for paths: [String]) throws -> [String: MDLSMetadata]? {
            // Use Pipe to capture the output
            let pipe = Pipe()
            let errorPipe = Pipe()
            let task = mdlsTask(for: paths, pipe: pipe, errorPipe: errorPipe)
            do {
                // Run the task
                try task.run()
                // Read the data from the pipe
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                    throw MDLSParseError.parseFailed("Error Output from mdls: \(errorOutput)")
                }
                // Check if there's any output captured
                if data.isEmpty {
                    throw MDLSParseError.parseFailed("No output captured from mdls")
                }
                // Attempt to parse the plist output into a Swift array of dictionaries
                var plistArray = [MDLSMetadata]()
                let properties = try PropertyListSerialization.propertyList(from: data, format: nil)
                if let dictionary = properties as? MDLSMetadata {
                    plistArray.append(dictionary)
                } else if let array = properties as? [MDLSMetadata] {
                    plistArray.append(contentsOf: array)
                } else {
                    throw MDLSParseError.parseFailed("Failed to parse plist output into expected format")
                }
                // Ensure the number of plist items matches the number of paths
                guard plistArray.count == paths.count else {
                    throw MDLSParseError.parseFailed("Number of plist items does not match the number of paths")
                }
                return Dictionary(zip(paths, plistArray), uniquingKeysWith: { _, last in last })
            } catch {
                throw MDLSParseError.parseFailed("Error running mdls: \(error)")
            }
        }

        static func mdlsTask(for paths: [String], pipe: Pipe, errorPipe: Pipe) -> Process {
            // Construct the `mdls` arguments: path + -name for each attribute + -plist - + -nullMarker ""
            let arguments = taskArguments(for: paths)
            let task = Process(launchPath: "/usr/bin/mdls", arguments: arguments)
            // Use Pipe to capture the output
            task.standardOutput = pipe
            task.standardError = errorPipe // Capture stderr in case there are errors
            return task
        }

        static func taskArguments(for paths: [String]) -> [String] {
            var arguments = paths
            for attribute in MDLSMetadataAttribute.allCases {
                arguments.append("-name")
                arguments.append(attribute.rawValue)
            }
            arguments.append("-plist") // Use plist format
            arguments.append("-") // Output to stdout
            arguments.append("-nullMarker") // Replace null attributes
            arguments.append("") // Substitute null values with empty string
            return arguments
        }
    }

    struct MDLSMetadata: Codable, Sendable {
        var fsName: String?
        var fsCreationDate: Date?
        var fsContentChangeDate: Date?
        var lastUsedDate: Date?
        var displayName: String?
        var bundleIdentifier: String?
        var executableArchitectures: [String]?
        var version: String?
        var copyright: String?
        var appStoreCategory: String?
        var appStoreCategoryType: String?
        var logicalSize: Int64?
        var physicalSize: Int64?

        init(attributes: [String: Any]) {
            fsName = attributes[MDLSMetadataAttribute.fsName.rawValue] as? String
            fsCreationDate = attributes[MDLSMetadataAttribute.fsCreationDate.rawValue] as? Date
            fsContentChangeDate = attributes[MDLSMetadataAttribute.fsContentChangeDate.rawValue] as? Date
            lastUsedDate = attributes[MDLSMetadataAttribute.lastUsedDate.rawValue] as? Date
            displayName = attributes[MDLSMetadataAttribute.displayName.rawValue] as? String
            bundleIdentifier = attributes[MDLSMetadataAttribute.bundleIdentifier.rawValue] as? String
            executableArchitectures = attributes[MDLSMetadataAttribute.executableArchitectures.rawValue] as? [String]
            version = attributes[MDLSMetadataAttribute.version.rawValue] as? String
            copyright = attributes[MDLSMetadataAttribute.copyright.rawValue] as? String
            appStoreCategory = attributes[MDLSMetadataAttribute.appStoreCategory.rawValue] as? String
            appStoreCategoryType = attributes[MDLSMetadataAttribute.appStoreCategoryType.rawValue] as? String
            logicalSize = attributes[MDLSMetadataAttribute.logicalSize.rawValue] as? Int64
            physicalSize = attributes[MDLSMetadataAttribute.physicalSize.rawValue] as? Int64
        }
    }

    enum MDLSMetadataAttribute: CaseIterable {
        case fsName
        case fsCreationDate
        case fsContentChangeDate
        case lastUsedDate
        case displayName
        case bundleIdentifier
        case executableArchitectures
        case version
        case copyright
        case appStoreCategory
        case appStoreCategoryType
        case logicalSize
        case physicalSize

        var rawValue: String {
            switch self {
            case .fsName: return kMDItemFSName as String
            case .fsCreationDate: return kMDItemFSCreationDate as String
            case .fsContentChangeDate: return kMDItemFSContentChangeDate as String
            case .lastUsedDate: return kMDItemLastUsedDate as String
            case .displayName: return kMDItemDisplayName as String
            case .bundleIdentifier: return kMDItemCFBundleIdentifier as String
            case .executableArchitectures: return kMDItemExecutableArchitectures as String
            case .version: return kMDItemVersion as String
            case .copyright: return kMDItemCopyright as String
            // The following attributes are not exposed in the CoreServices framework headers
            case .appStoreCategory: return "kMDItemAppStoreCategory"
            case .appStoreCategoryType: return "kMDItemAppStoreCategoryType"
            case .logicalSize: return "kMDItemLogicalSize"
            case .physicalSize: return "kMDItemPhysicalSize"
            }
        }
    }

#endif
