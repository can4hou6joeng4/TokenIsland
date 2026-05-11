import Foundation
import TokenIslandCore

final class HookServer: @unchecked Sendable {
    typealias EventHandler = @Sendable (HookEvent) -> Void

    private var listenFD: Int32 = -1
    private let acceptQueue = DispatchQueue(label: "tokenisland.hook.accept", qos: .utility)
    private let handler: EventHandler
    private let stateLock = NSLock()
    private var _isRunning = false

    private var isRunning: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isRunning }
        set { stateLock.lock(); _isRunning = newValue; stateLock.unlock() }
    }

    init(handler: @escaping EventHandler) {
        self.handler = handler
    }

    func start() {
        guard !isRunning else { return }
        let path = TokenIslandCore.socketPath
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            NSLog("[HookServer] socket() failed")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { dst in
            pathBytes.withUnsafeBytes { src in
                let copyLen = min(src.count, dst.count - 1)
                dst.copyMemory(from: UnsafeRawBufferPointer(start: src.baseAddress, count: copyLen))
            }
        }

        let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, addrSize)
            }
        }
        guard bindResult == 0 else {
            NSLog("[HookServer] bind() failed: \(String(cString: strerror(errno)))")
            close(fd)
            return
        }
        guard listen(fd, 16) == 0 else {
            NSLog("[HookServer] listen() failed")
            close(fd)
            return
        }
        chmod(path, 0o600)

        listenFD = fd
        isRunning = true
        NSLog("[HookServer] listening on \(path)")

        acceptQueue.async { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        isRunning = false
        if listenFD >= 0 {
            close(listenFD)
            listenFD = -1
        }
        unlink(TokenIslandCore.socketPath)
    }

    private func acceptLoop() {
        while isRunning {
            var clientAddr = sockaddr()
            var clientLen = socklen_t(MemoryLayout<sockaddr>.size)
            let clientFD = accept(listenFD, &clientAddr, &clientLen)
            if clientFD < 0 {
                if !isRunning { return }
                continue
            }
            handleClient(clientFD)
        }
    }

    private func handleClient(_ fd: Int32) {
        var buffer = Data()
        var tmp = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = tmp.withUnsafeMutableBufferPointer { recv(fd, $0.baseAddress!, 4096, 0) }
            if n <= 0 { break }
            buffer.append(tmp, count: n)
        }
        close(fd)

        for lineData in buffer.split(separator: 0x0A) where !lineData.isEmpty {
            guard let event = HookEvent.decode(Data(lineData)) else {
                NSLog("[HookServer] failed to decode line of \(lineData.count) bytes")
                continue
            }
            NSLog("[HookServer] event source=\(event.source.rawValue) kind=\(event.kind.rawValue) session=\(event.sessionId) tool=\(event.toolName ?? "-")")
            handler(event)
        }
    }
}
