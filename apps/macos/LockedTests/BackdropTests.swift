import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@Suite struct BackdropImport {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    /// A plain PNG of the given size, written to the temporary folder.
    func png(width: Int, height: Int) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "source.png")
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let writer = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(writer, context.makeImage()!, nil)
        #expect(CGImageDestinationFinalize(writer))
        return url
    }

    @Test func `a picture is saved as a JPEG no wider than 4K, and the block page moves beside it`() throws {
        try Backdrop.set(from: png(width: 5000, height: 50), in: folder)
        let saved = try #require(CGImageSourceCreateWithURL(Backdrop.image(in: folder) as CFURL, nil))
        #expect(CGImageSourceGetType(saved) as String? == UTType.jpeg.identifier)
        #expect(CGImageSourceCreateImageAtIndex(saved, 0, nil)?.width == 3840)

        let bundled = folder.appending(path: "bundled.html")
        try Data("page".utf8).write(to: bundled)
        #expect(Backdrop.page(bundled: bundled, in: folder) == folder.appending(path: "block.html"))
        Backdrop.remove(in: folder)
        #expect(Backdrop.page(bundled: bundled, in: folder) == bundled)
    }

    @Test func `a file that isn't a picture throws and keeps the current backdrop`() throws {
        try Backdrop.set(from: png(width: 10, height: 10), in: folder)
        let before = try Data(contentsOf: Backdrop.image(in: folder))
        let text = folder.appending(path: "notes.txt")
        try Data("not a picture".utf8).write(to: text)
        #expect(throws: Backdrop.Unreadable.self) { try Backdrop.set(from: text, in: folder) }
        #expect(try Data(contentsOf: Backdrop.image(in: folder)) == before)
    }
}
