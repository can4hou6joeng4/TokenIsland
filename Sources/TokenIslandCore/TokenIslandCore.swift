import Foundation

public enum TokenIslandCore {
    public static let socketPath: String = {
        let uid = getuid()
        return "/tmp/tokenisland-\(uid).sock"
    }()

    public static let version = "0.1.0-dev"
}
