//
//  Clip.swift
//  SimpleNotch
//
//  One thing that was copied: text, a link, an image or a reference to files.
//  See "Clip" and "Pinned clip" in CONTEXT.md.
//

import AppKit
import KeyboardShortcuts

struct Clip: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case text, link, image, file
    }

    let id: UUID
    var kind: Kind
    /// The copied text, or the link's absolute string.
    var text: String?
    /// File paths for a file reference Clip.
    var filePaths: [String]?
    /// File name of the downscaled PNG inside the Clipboard images folder.
    var imageFileName: String?
    var imagePixelSize: CGSize?
    /// Bundle identifier of the app that was frontmost when the Clip was copied.
    var sourceBundleID: String?
    var date: Date
    var pinned: Bool
    /// Identifies the content, so copying the same thing again moves the
    /// existing Clip to the top instead of adding a duplicate.
    var contentKey: String

    var symbolName: String {
        switch kind {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .file: "doc"
        }
    }

    var fileURLs: [URL] { (filePaths ?? []).map { URL(fileURLWithPath: $0) } }

    /// The text matched by search.
    var searchableText: String {
        switch kind {
        case .text, .link: text ?? ""
        case .file: fileURLs.map(\.lastPathComponent).joined(separator: " ")
        case .image: "image"
        }
    }
}

extension KeyboardShortcuts.Name {
    static let openClipboard = Self("openClipboard", default: .init(.v, modifiers: [.command, .shift]))
}
