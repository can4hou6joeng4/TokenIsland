import XCTest
@testable import TokenIsland

@MainActor
final class HookInstallerTests: XCTestCase {
    func testBridgeCandidatePathsIncludePackagedHelpersDirectory() {
        let appURL = URL(fileURLWithPath: "/tmp/TokenIsland.app")
        let executableURL = appURL.appendingPathComponent("Contents/MacOS/TokenIsland")

        let candidates = HookInstaller.bridgeCandidatePaths(
            bundleURL: appURL,
            executableURL: executableURL
        )

        XCTAssertEqual(
            candidates.first?.path,
            "/tmp/TokenIsland.app/Contents/Helpers/tokenisland-bridge"
        )
        XCTAssertTrue(candidates.contains(URL(fileURLWithPath: "/tmp/TokenIsland.app/Contents/MacOS/tokenisland-bridge")))
    }

    func testBridgeCandidatePathsIncludeSwiftPMSiblingBinary() {
        let buildDir = URL(fileURLWithPath: "/tmp/.build/arm64-apple-macosx/debug")
        let bundleURL = buildDir.appendingPathComponent("TokenIsland")
        let executableURL = buildDir.appendingPathComponent("TokenIsland")

        let candidates = HookInstaller.bridgeCandidatePaths(
            bundleURL: bundleURL,
            executableURL: executableURL
        )

        XCTAssertTrue(candidates.contains(buildDir.appendingPathComponent("tokenisland-bridge")))
    }
}
