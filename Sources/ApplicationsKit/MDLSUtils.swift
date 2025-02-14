//
//  MDLSUtils.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/1/20.
//

import Foundation

#if os(macOS)

@available(macOS 10.15, *)
enum MDLSParseError: LocalizedError, Sendable {
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .parseFailed(let message):
            return message
        }
    }
}

@available(macOS 10.15, *)
typealias MDLSMetadata = [String: Any]

@available(macOS 10.15, *)
enum MDLSUtils: Sendable {
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
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/mdls")

        // Construct the `mdls` arguments: path + -name for each attribute + -plist - + -nullMarker ""
        let arguments = taskArguments(for: paths)
        task.arguments = arguments

        // Use Pipe to capture the output
        task.standardOutput = pipe
        task.standardError = errorPipe // Capture stderr in case there are errors

        return task
    }

    static func taskArguments(for paths: [String]) -> [String] {
        var arguments = paths
        for attribute in attributes {
            arguments.append("-name")
            arguments.append(attribute)
        }
        arguments.append("-plist") // Use plist format
        arguments.append("-") // Output to stdout
        arguments.append("-nullMarker") // Replace null attributes
        arguments.append("") // Substitute null values with empty string
        return arguments
    }

    // Define the required metadata attributes to include in the output
    static let attributes = [
        "kMDItemFSCreationDate",
        "kMDItemFSContentChangeDate",
        "kMDItemLastUsedDate",
        "kMDItemDisplayName",
        "kMDItemAppStoreCategory",
        "kMDItemCFBundleIdentifier",
        "kMDItemExecutableArchitectures",
        "kMDItemFSName",
        "kMDItemVersion",
        "kMDItemLogicalSize",
        "kMDItemPhysicalSize"
    ]
}

#endif
