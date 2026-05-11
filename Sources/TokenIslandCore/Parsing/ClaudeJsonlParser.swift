import Foundation

public enum ClaudeJsonlParser {
    private static let rawKeys = ["input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"]
    private static let billableKeys = ["input_tokens", "output_tokens", "cache_creation_input_tokens"]
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public static func parse(fileURL: URL, into snapshot: inout TokenSnapshot) {
        guard let stream = InputStream(url: fileURL) else { return }
        stream.open()
        defer { stream.close() }

        let reader = LineReader(stream: stream)
        while let line = reader.nextLine() {
            guard line.contains("\"usage\"") else { continue }
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            guard (obj["type"] as? String) == "assistant",
                  let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any]
            else { continue }

            var raw = 0
            for k in rawKeys {
                if let n = usage[k] as? Int { raw += n }
                else if let n = usage[k] as? Double { raw += Int(n) }
            }
            var billable = 0
            for k in billableKeys {
                if let n = usage[k] as? Int { billable += n }
                else if let n = usage[k] as? Double { billable += Int(n) }
            }
            guard raw > 0 || billable > 0 else { continue }

            guard let timestampString = obj["timestamp"] as? String,
                  let date = parseISO(timestampString)
            else { continue }

            let model = (message["model"] as? String) ?? "claude-unknown"
            let bucket = BucketKey(date: date)
            snapshot.bump(bucket: bucket, model: model, counts: TokenCounts(raw: raw, billable: billable))
        }
    }

    public static func parseISO(_ s: String) -> Date? {
        if let d = isoFormatter.date(from: s) { return d }
        return isoFormatterNoFraction.date(from: s)
    }
}
