import Foundation

public enum CodexJsonlParser {
    public static func parse(fileURL: URL, into snapshot: inout TokenSnapshot) {
        guard let stream = InputStream(url: fileURL) else { return }
        stream.open()
        defer { stream.close() }

        let reader = LineReader(stream: stream)
        var currentModel: String?
        var prevTotal: Double = 0
        var first = true

        while let line = reader.nextLine() {
            let hasContext = line.contains("\"turn_context\"")
            let hasCount = line.contains("\"token_count\"")
            guard hasContext || hasCount else { continue }
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = obj["payload"] as? [String: Any]
            else { continue }

            if (obj["type"] as? String) == "turn_context" {
                if let m = (payload["model"] as? String)?.trimmingCharacters(in: .whitespaces), !m.isEmpty {
                    currentModel = m
                }
            }

            if (payload["type"] as? String) == "token_count" {
                guard let info = payload["info"] as? [String: Any],
                      let totUsage = info["total_token_usage"] as? [String: Any]
                else { continue }
                let totalTokens: Double
                if let n = totUsage["total_tokens"] as? Int { totalTokens = Double(n) }
                else if let n = totUsage["total_tokens"] as? Double { totalTokens = n }
                else { continue }

                let delta = first ? totalTokens : max(totalTokens - prevTotal, 0)
                prevTotal = totalTokens
                first = false
                guard delta > 0 else { continue }

                let tsString = (payload["timestamp"] as? String) ?? (obj["timestamp"] as? String)
                guard let s = tsString, let date = ClaudeJsonlParser.parseISO(s) else { continue }

                let model = currentModel ?? "codex-unknown"
                let bucket = BucketKey(date: date)
                let di = Int(delta)
                snapshot.bump(bucket: bucket, model: model, counts: TokenCounts(raw: di, billable: di))
            }
        }
    }
}
