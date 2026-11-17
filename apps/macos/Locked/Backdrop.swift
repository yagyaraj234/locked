import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The user's own picture, shown behind the block screen and the in-tab block page.
nonisolated enum Backdrop {
    struct Unreadable: Error {}

    static let folder = URL.applicationSupportDirectory.appending(path: "Locked")

    static func image(in folder: URL = folder) -> URL { folder.appending(path: "background.jpg") }

    /// Saves `source` as the backdrop: a JPEG whatever it was, because browsers can't show
    /// HEIC, and no larger than a 4K display needs. A file that isn't a picture throws and
    /// leaves the current backdrop alone.
    // ponytail: decodes on the caller's thread, a beat for a huge photo; make it @concurrent if it ever beachballs.
    static func set(from source: URL, in folder: URL = folder) throws {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,  // honour the camera's rotation
                       kCGImageSourceThumbnailMaxPixelSize: 3840] as CFDictionary
        guard let reader = CGImageSourceCreateWithURL(source as CFURL, nil),
              let picture = CGImageSourceCreateThumbnailAtIndex(reader, 0, options) else { throw Unreadable() }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Written beside the old one and swapped in, so a failed write can't lose it.
        let draft = folder.appending(path: "background.tmp")
        guard let writer = CGImageDestinationCreateWithURL(draft as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw Unreadable() }
        CGImageDestinationAddImage(writer, picture, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(writer) else { throw Unreadable() }
        _ = try FileManager.default.replaceItemAt(image(in: folder), withItemAt: draft)
    }

    static func remove(in folder: URL = folder) {
        try? FileManager.default.removeItem(at: image(in: folder))
    }

    /// The block page to open. With a backdrop it is a copy beside the picture, which the
    /// page finds by a relative address; copied each time so an app update never leaves it stale.
    static func page(bundled: URL, in folder: URL = folder) -> URL {
        let copy = folder.appending(path: "block.html")
        guard FileManager.default.fileExists(atPath: image(in: folder).path),
              (try? Data(contentsOf: bundled).write(to: copy)) != nil else { return bundled }
        return copy
    }
}
