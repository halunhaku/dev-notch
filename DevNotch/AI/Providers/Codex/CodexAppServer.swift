import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "CodexAppServer")

enum CodexServerError: LocalizedError, Sendable {
    case processNotRunning
    case failedToStart(String)
    case writeFailed(String)
    case timeout(method: String)
    case missingResult
    case cancelled

    var errorDescription: String? {
        switch self {
        case .processNotRunning:
            return "Codex app-server process is not running"
        case .failedToStart(let reason):
            return "Failed to launch codex app-server: \(reason)"
        case .writeFailed(let reason):
            return "Failed to write to codex stdin: \(reason)"
        case .timeout(let method):
            return "Request '\(method)' timed out waiting for response"
        case .missingResult:
            return "Response missing expected 'result' payload"
        case .cancelled:
            return "Request cancelled"
        }
    }
}

/// Actor managing the long-lived `codex app-server` child process and JSON-RPC multiplexing.
actor CodexAppServer {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var readerTask: Task<Void, Never>?
    private var nextRequestId: Int = 1
    private var pendingRequests: [Int: CheckedContinuation<Data, Error>] = [:]

    /// Notification handler invoked for server-push events (e.g. rate limit updates).
    var onNotification: (@Sendable (String, Data) -> Void)?

    /// Process termination handler.
    var onTermination: (@Sendable (Int32) -> Void)?

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    /// Builds a comprehensive PATH environment so node/codex can be resolved regardless of LaunchServices environment.
    private func buildProcessEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        var pathDirs: [String] = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            NSString(string: "~/.local/bin").expandingTildeInPath,
            NSString(string: "~/.cargo/bin").expandingTildeInPath,
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        // Inspect NVM directories if installed
        let nvmDir = NSString(string: "~/.nvm/versions/node").expandingTildeInPath
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) {
            for ver in versions {
                let bin = "\(nvmDir)/\(ver)/bin"
                if FileManager.default.fileExists(atPath: bin) {
                    pathDirs.insert(bin, at: 0)
                }
            }
        }

        if let existing = env["PATH"], !existing.isEmpty {
            pathDirs.append(existing)
        }

        env["PATH"] = pathDirs.joined(separator: ":")
        return env
    }

    /// Launches the `codex app-server` child process.
    func start(executablePath: String) throws {
        guard !isRunning else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = ["app-server"]
        proc.environment = buildProcessEnvironment()

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        proc.terminationHandler = { [weak self] p in
            let code = p.terminationStatus
            logger.warning("Codex app-server process exited with status: \(code)")
            Task { [weak self] in
                await self?.handleProcessTerminated(exitCode: code)
            }
        }

        do {
            try proc.run()
        } catch {
            logger.error("Failed to run codex app-server: \(error.localizedDescription)")
            throw CodexServerError.failedToStart(error.localizedDescription)
        }

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout

        logger.info("Codex app-server started successfully (PID: \(proc.processIdentifier))")
        startStdoutReader(stdout: stdout)
    }

    /// Stops the child process gracefully.
    func stop() {
        readerTask?.cancel()
        readerTask = nil

        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: CodexServerError.cancelled)
        }
        pendingRequests.removeAll()

        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        logger.info("Codex app-server stopped")
    }

    /// Sends a JSON-RPC request and awaits the matched response.
    func sendRequest<P: Encodable & Sendable, R: Decodable & Sendable>(
        method: String,
        params: P,
        timeoutSeconds: Double = 8.0
    ) async throws -> R {
        guard isRunning, stdinPipe != nil else {
            throw CodexServerError.processNotRunning
        }

        let reqId = nextRequestId
        nextRequestId += 1

        let request = JSONRPCRequest(id: reqId, method: method, params: params)
        var messageData = try JSONEncoder().encode(request)
        messageData.append(contentsOf: [0x0A]) // \n newline delimiter
        let payload = messageData

        return try await withThrowingTaskGroup(of: R.self) { group in
            // Task 1: Timeout watchdog
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw CodexServerError.timeout(method: method)
            }

            // Task 2: Dispatch and wait for response
            group.addTask { [weak self, payload] in
                guard let self = self else { throw CodexServerError.cancelled }
                let rawData = try await self.waitForResponse(for: reqId, sending: payload)
                let response = try JSONDecoder().decode(JSONRPCGenericResponse<R>.self, from: rawData)
                if let errorPayload = response.error {
                    throw errorPayload
                }
                guard let result = response.result else {
                    throw CodexServerError.missingResult
                }
                return result
            }

            do {
                let result = try await group.next()!
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                self.cancelPendingRequest(id: reqId)
                throw error
            }
        }
    }

    private func waitForResponse(for reqId: Int, sending data: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            registerPendingRequest(id: reqId, continuation: continuation)
            do {
                try stdinPipe?.fileHandleForWriting.write(contentsOf: data)
            } catch {
                cancelPendingRequest(id: reqId)
                continuation.resume(throwing: CodexServerError.writeFailed(error.localizedDescription))
            }
        }
    }

    /// Sends a JSON-RPC notification (fire and forget).
    func sendNotification<P: Encodable & Sendable>(method: String, params: P) throws {
        guard isRunning, let stdin = stdinPipe else {
            throw CodexServerError.processNotRunning
        }

        let notification = JSONRPCNotification(method: method, params: params)
        let data = try JSONEncoder().encode(notification)
        var messageData = data
        messageData.append(contentsOf: [0x0A])

        try stdin.fileHandleForWriting.write(contentsOf: messageData)
    }

    private func registerPendingRequest(id: Int, continuation: CheckedContinuation<Data, Error>) {
        pendingRequests[id] = continuation
    }

    private func cancelPendingRequest(id: Int) {
        if let cont = pendingRequests.removeValue(forKey: id) {
            cont.resume(throwing: CodexServerError.cancelled)
        }
    }

    private func handleProcessTerminated(exitCode: Int32) {
        stop()
        onTermination?(exitCode)
    }

    private func startStdoutReader(stdout: Pipe) {
        let handle = stdout.fileHandleForReading
        readerTask = Task.detached { [weak self] in
            do {
                for try await line in handle.bytes.lines {
                    guard let lineData = line.data(using: .utf8), !lineData.isEmpty else { continue }
                    await self?.handleIncomingLine(lineData)
                }
            } catch {
                logger.debug("Stdout line reader finished or error: \(error.localizedDescription)")
            }
        }
    }

    private func handleIncomingLine(_ data: Data) {
        do {
            let envelope = try JSONDecoder().decode(JSONRPCResponseEnvelope.self, from: data)

            // If it has an ID, route to matching pending request continuation
            if let id = envelope.id {
                if let continuation = pendingRequests.removeValue(forKey: id) {
                    continuation.resume(returning: data)
                } else {
                    logger.debug("Received response for unknown request ID: \(id)")
                }
                return
            }

            // If it has a method, it is a notification
            if let method = envelope.method {
                onNotification?(method, data)
                return
            }
        } catch {
            logger.debug("Unparseable line from codex app-server: \(String(data: data, encoding: .utf8) ?? "")")
        }
    }

    deinit {
        readerTask?.cancel()
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
    }
}

private struct JSONRPCGenericResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let id: Int?
    let result: T?
    let error: JSONRPCErrorPayload?
}
