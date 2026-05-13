import Foundation

enum SparkleConfiguration {
    static func shouldStartUpdater(feedURLString: String?) -> Bool {
        guard let feedURLString,
              !feedURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !feedURLString.contains("REPLACE_WITH_OWNER"),
              !feedURLString.contains("REPLACE_WITH_ED25519_SIGNATURE"),
              let url = URL(string: feedURLString),
              url.scheme == "https",
              url.host?.isEmpty == false
        else {
            return false
        }
        return true
    }

    static func shouldStartUpdater(bundle: Bundle = .main) -> Bool {
        shouldStartUpdater(feedURLString: bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String)
    }
}
