import XCTest

@testable import QingWu

final class HtmlManagerTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QingWu PPT Tests \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        try super.tearDownWithError()
    }

    func testPPTLocalImageUsesEncodedFileURL() throws {
        let imageURL =
            tempDirectory
            .appendingPathComponent("i", isDirectory: true)
            .appendingPathComponent("CleanShot image.png")
        try FileManager.default.createDirectory(
            at: imageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0]).write(to: imageURL)

        let markdown = "![](/i/CleanShot image.png)"
        let processed = HtmlManager.processImagesInMarkdown(markdown, imagesStorage: tempDirectory)

        XCTAssertEqual(processed, "![](\(imageURL.absoluteString))")
    }
}
