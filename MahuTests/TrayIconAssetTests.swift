import CoreGraphics
import ImageIO
import XCTest

final class TrayIconAssetTests: XCTestCase {
    func testTrayTemplateAssetFilesUseTransparentBackgroundAndNonEmptyGlyph() throws {
        let assetFiles = try trayTemplateAssetFiles()
        let oneXMetrics = try trayTemplateAssetMetrics(named: assetFiles.oneX)
        let twoXMetrics = try trayTemplateAssetMetrics(named: assetFiles.twoX)

        assertBasicAssetContract(oneXMetrics, expectedWidth: 18, expectedHeight: 18)
        assertBasicAssetContract(twoXMetrics, expectedWidth: 36, expectedHeight: 36)
    }

    func testTrayTemplateRetinaAssetScalesGlyphRelativeToOneX() throws {
        let assetFiles = try trayTemplateAssetFiles()
        let oneXMetrics = try trayTemplateAssetMetrics(named: assetFiles.oneX)
        let twoXMetrics = try trayTemplateAssetMetrics(named: assetFiles.twoX)
        let oneXGlyphBounds = try XCTUnwrap(oneXMetrics.glyphBounds)
        let twoXGlyphBounds = try XCTUnwrap(twoXMetrics.glyphBounds)

        XCTAssertGreaterThan(
            twoXMetrics.opaqueGlyphPixelCount,
            oneXMetrics.opaqueGlyphPixelCount * 2,
            "Expected @2x asset to contain a meaningfully larger glyph mask than the 1x asset"
        )
        XCTAssertGreaterThan(
            twoXGlyphBounds.width,
            Int(Double(oneXGlyphBounds.width) * 1.5),
            "Expected @2x asset to scale glyph width beyond the 1x bounds"
        )
        XCTAssertGreaterThan(
            twoXGlyphBounds.height,
            Int(Double(oneXGlyphBounds.height) * 1.5),
            "Expected @2x asset to scale glyph height beyond the 1x bounds"
        )
    }

    func testTrayTemplateImageSetContainsOnlyExpectedTransparentGlyphAssets() throws {
        let assetFiles = try trayTemplateAssetFiles()
        let imageSetURL = try XCTUnwrap(trayTemplateImageSetURL())
        let resources = try FileManager.default.contentsOfDirectory(
            at: imageSetURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        XCTAssertEqual(
            Set(resources.map(\.lastPathComponent)),
            ["Contents.json", assetFiles.oneX, assetFiles.twoX]
        )
    }

    private func trayTemplateAssetFiles() throws -> TrayTemplateAssetFiles {
        let imageSetURL = try XCTUnwrap(trayTemplateImageSetURL())
        let contentsURL = imageSetURL.appendingPathComponent("Contents.json")
        let data = try Data(contentsOf: contentsURL)
        let contents = try JSONDecoder().decode(TrayTemplateContents.self, from: data)

        let oneX = try XCTUnwrap(
            contents.images.first { $0.scale == "1x" }?.filename,
            "Expected TrayIconTemplate.imageset to declare a 1x filename"
        )
        let twoX = try XCTUnwrap(
            contents.images.first { $0.scale == "2x" }?.filename,
            "Expected TrayIconTemplate.imageset to declare a 2x filename"
        )

        return TrayTemplateAssetFiles(oneX: oneX, twoX: twoX)
    }

    private func assertBasicAssetContract(
        _ metrics: TrayTemplateAssetMetrics,
        expectedWidth: Int,
        expectedHeight: Int
    ) {
        XCTAssertEqual(metrics.canvasWidth, expectedWidth)
        XCTAssertEqual(metrics.canvasHeight, expectedHeight)
        for (index, alpha) in metrics.cornerAlphas.enumerated() {
            XCTAssertLessThan(
                alpha,
                0.05,
                "Expected transparent corner \(index) in \(metrics.fileName), got alpha \(alpha)"
            )
        }
        XCTAssertGreaterThan(
            metrics.transparentPixelCount,
            0,
            "Expected \(metrics.fileName) to contain transparent background pixels"
        )
        XCTAssertGreaterThan(
            metrics.opaqueGlyphPixelCount,
            0,
            "Expected \(metrics.fileName) to contain non-transparent glyph pixels"
        )
        XCTAssertNotNil(metrics.glyphBounds, "Expected \(metrics.fileName) to contain a visible glyph")
    }

    private func trayTemplateAssetMetrics(named fileName: String) throws -> TrayTemplateAssetMetrics {
        let url = try XCTUnwrap(trayTemplateAssetURL(named: fileName))
        let data = try Data(contentsOf: url)
        let imageSource = try XCTUnwrap(
            CGImageSourceCreateWithData(data as CFData, nil),
            "Unable to decode image source for \(fileName)"
        )
        let image = try XCTUnwrap(
            CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
            "Unable to decode raster for \(fileName)"
        )

        let width = image.width
        let height = image.height
        var rgbaPixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try rgbaPixels.withUnsafeMutableBytes { bytes in
            try XCTUnwrap(
                CGContext(
                    data: bytes.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ),
                "Unable to create RGBA bitmap context for \(fileName)"
            )
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var transparentPixelCount = 0
        var opaqueGlyphPixelCount = 0
        var minX = width
        var maxX = -1
        var minY = height
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let alpha = alphaComponent(in: rgbaPixels, width: width, x: x, y: y)
                if alpha < 0.05 {
                    transparentPixelCount += 1
                }
                if alpha > 0.2 {
                    opaqueGlyphPixelCount += 1
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }

        let glyphBounds = maxX >= minX && maxY >= minY
            ? PixelBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
            : nil
        let cornerPoints = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
        let cornerAlphas = cornerPoints.map { alphaComponent(in: rgbaPixels, width: width, x: $0.0, y: $0.1) }

        return TrayTemplateAssetMetrics(
            fileName: fileName,
            canvasWidth: width,
            canvasHeight: height,
            transparentPixelCount: transparentPixelCount,
            opaqueGlyphPixelCount: opaqueGlyphPixelCount,
            cornerAlphas: cornerAlphas,
            glyphBounds: glyphBounds
        )
    }

    private func trayTemplateAssetURL(named fileName: String) -> URL? {
        trayTemplateImageSetURL()?.appendingPathComponent(fileName)
    }

    private func trayTemplateImageSetURL() -> URL? {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return repositoryRoot
            .appendingPathComponent("Mahu")
            .appendingPathComponent("Assets.xcassets")
            .appendingPathComponent("TrayIconTemplate.imageset")
    }

    private func alphaComponent(in rgbaPixels: [UInt8], width: Int, x: Int, y: Int) -> Double {
        let offset = ((y * width) + x) * 4
        return Double(rgbaPixels[offset + 3]) / 255
    }
}

private struct TrayTemplateAssetMetrics {
    let fileName: String
    let canvasWidth: Int
    let canvasHeight: Int
    let transparentPixelCount: Int
    let opaqueGlyphPixelCount: Int
    let cornerAlphas: [Double]
    let glyphBounds: PixelBounds?
}

private struct PixelBounds {
    let minX: Int
    let maxX: Int
    let minY: Int
    let maxY: Int

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
}

private struct TrayTemplateContents: Decodable {
    struct Image: Decodable {
        let filename: String?
        let scale: String
    }

    let images: [Image]
}

private struct TrayTemplateAssetFiles {
    let oneX: String
    let twoX: String
}
