import XCTest
@testable import TokenIsland

final class SparkleConfigurationTests: XCTestCase {
    func testUpdaterDoesNotStartWithoutFeedURL() {
        XCTAssertFalse(SparkleConfiguration.shouldStartUpdater(feedURLString: nil))
    }

    func testUpdaterDoesNotStartForPlaceholderFeedURL() {
        XCTAssertFalse(
            SparkleConfiguration.shouldStartUpdater(
                feedURLString: "https://raw.githubusercontent.com/REPLACE_WITH_OWNER/TokenIsland/main/appcast.xml"
            )
        )
    }

    func testUpdaterDoesNotStartForInvalidFeedURL() {
        XCTAssertFalse(SparkleConfiguration.shouldStartUpdater(feedURLString: "not a url"))
    }

    func testUpdaterStartsForHTTPSFeedURL() {
        XCTAssertTrue(
            SparkleConfiguration.shouldStartUpdater(
                feedURLString: "https://example.com/TokenIsland/appcast.xml"
            )
        )
    }
}
