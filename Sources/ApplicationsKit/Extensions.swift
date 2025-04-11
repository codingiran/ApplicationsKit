//
//  Extensions.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/1/20.
//

import Foundation

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = capitalizingFirstLetter()
    }
}

extension URL {
    init(fileURLPath path: String) {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            self.init(filePath: path)
        } else {
            self.init(fileURLWithPath: path)
        }
    }

    var filePath: String {
        if #available(macOS 13.0, macCatalyst 16.0, *) {
            path(percentEncoded: false)
        } else {
            path
        }
    }

    func localizedName() -> String {
        do {
            let resourceValues = try self.resourceValues(forKeys: [.localizedNameKey])
            return resourceValues.localizedName?.replacingOccurrences(of: ".app", with: "") ?? lastPathComponent.replacingOccurrences(of: ".app", with: "")
        } catch {
            return lastPathComponent.replacingOccurrences(of: ".app", with: "")
        }
    }

    var isRestricted: Bool {
        if path.contains("/Applications/Safari") || path.contains(Bundle.main.name) || path.contains("/Applications/Utilities") {
            return true
        } else {
            return false
        }
    }

    var isSymlink: Bool {
        do {
            let _ = try checkResourceIsReachable()
            let resourceValues = try self.resourceValues(forKeys: [.isSymbolicLinkKey])
            return resourceValues.isSymbolicLink == true
        } catch {
            return false
        }
    }

    func appendingPath(_ path: String) -> URL {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            return self.appending(path: path)
        } else {
            return appendingPathComponent(path)
        }
    }
}

extension Bundle {
    var name: String {
        func string(for key: String) -> String? {
            object(forInfoDictionaryKey: key) as? String
        }
        return string(for: "CFBundleDisplayName")
            ?? string(for: "CFBundleName")
            ?? "N/A"
    }

    var version: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }

    var buildVersion: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

    var bundleId: String {
        bundleIdentifier ?? "N/A"
    }
}

extension FileManager {
    func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.filePath)
    }

    func fileExists(at url: URL, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        fileExists(atPath: url.filePath, isDirectory: isDirectory)
    }
}

extension Array {
    subscript(safeIndex index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#if canImport(AppKit)

    import AppKit

    @available(macOS 10.15, *)
    extension NSImage {
        func convertICNSToPNGData(size: NSSize? = nil) -> Data? {
            // Resize the icon to the specified size
            let resizedIcon: NSImage = {
                guard let size else {
                    return self
                }
                let resizedIcon = NSImage(size: size)
                resizedIcon.lockFocus()
                draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
                resizedIcon.unlockFocus()
                return resizedIcon
            }()

            // Convert the resized icon to PNG format
            guard let resizedImageData = resizedIcon.tiffRepresentation,
                  let resizedBitmap = NSBitmapImageRep(data: resizedImageData),
                  let pngData = resizedBitmap.representation(using: .png, properties: [:])
            else {
                return nil
            }

            return pngData
        }

        func convertICNSToPNGImage(size _: NSSize? = nil) -> NSImage? {
            guard let pngData = convertICNSToPNGData() else {
                return nil
            }
            return NSImage(data: pngData)
        }
    }

    extension NSImage: @retroactive @unchecked Sendable {}

    extension Foundation.Process {
        convenience init(launchPath: String, arguments: [String]?) {
            self.init()
            executableURL = URL(fileURLPath: launchPath)
            self.arguments = arguments
        }
    }

#endif
