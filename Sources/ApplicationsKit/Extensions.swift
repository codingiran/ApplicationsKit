//
//  Extensions.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/1/20.
//

import AppKit
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
    var filePath: String {
        if #available(macOS 13.0, macCatalyst 16.0, *) {
            path(percentEncoded: true)
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
        fileExists(atPath: url.path)
    }

    func fileExists(at url: URL, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        fileExists(atPath: url.path, isDirectory: isDirectory)
    }
}

#if os(macOS)

@available(macOS 10.15, *)
extension NSImage {
    func convertICNSToPNG(size: NSSize) -> NSImage? {
        // Resize the icon to the specified size
        let resizedIcon = NSImage(size: size)
        resizedIcon.lockFocus()
        draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        resizedIcon.unlockFocus()

        // Convert the resized icon to PNG format
        if let resizedImageData = resizedIcon.tiffRepresentation,
           let resizedBitmap = NSBitmapImageRep(data: resizedImageData),
           let pngData = resizedBitmap.representation(using: .png, properties: [:])
        {
            return NSImage(data: pngData)
        }

        return nil
    }
}

#endif
