import Foundation

final class LineReader {
    private let stream: InputStream
    private var buffer = Data()
    private let chunkSize = 64 * 1024
    private var eof = false

    init(stream: InputStream) {
        self.stream = stream
    }

    func nextLine() -> String? {
        while !eof {
            if let nlIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.subdata(in: 0..<nlIndex)
                buffer.removeSubrange(0...nlIndex)
                if let s = String(data: lineData, encoding: .utf8) { return s }
                return ""
            }
            if !readChunk() { break }
        }
        if !buffer.isEmpty {
            let lineData = buffer
            buffer.removeAll(keepingCapacity: false)
            return String(data: lineData, encoding: .utf8)
        }
        return nil
    }

    private func readChunk() -> Bool {
        var tmp = [UInt8](repeating: 0, count: chunkSize)
        let n = tmp.withUnsafeMutableBufferPointer { stream.read($0.baseAddress!, maxLength: chunkSize) }
        guard n > 0 else { eof = true; return false }
        buffer.append(tmp, count: n)
        return true
    }
}
