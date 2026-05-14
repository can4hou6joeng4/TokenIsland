import XCTest

final class AppIconPackagingTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testInfoPlistReferencesPackagedAppIcon() throws {
        let plistURL = repositoryRoot.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "AppIcon")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: repositoryRoot.appendingPathComponent("Resources/AppIcon.icns").path),
            "Resources/AppIcon.icns must exist so build.sh can package the icon referenced by Info.plist."
        )
    }

    func testBuildScriptCopiesAppIconResourceIntoBundle() throws {
        let scriptURL = repositoryRoot.appendingPathComponent("build.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(script.contains("APP_ICON=\"Resources/AppIcon.icns\""))
        XCTAssertTrue(script.contains("cp \"$APP_ICON\" \"$APP_BUNDLE/Contents/Resources/AppIcon.icns\""))
    }
}
