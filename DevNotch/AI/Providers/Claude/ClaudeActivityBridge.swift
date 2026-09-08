import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "ClaudeActivityBridge")

/// Observes session telemetry and hook events written by DevNotchClaudeBridge.
final class ClaudeActivityBridge: @unchecked Sendable {
    static let sessionDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DevNotch/Claude", isDirectory: true)
    }()

    static let sessionFileURL: URL = {
        sessionDirectoryURL.appendingPathComponent("session.json")
    }()

    private let lock = NSLock()
    private var _activitySnapshot: AIActivitySnapshot = AIActivitySnapshot(state: .idle)
    private var _contextMetric: AIContextMetric?
    private var _sessionCostMetric: AISessionCostMetric?
    private var _isTransientDone: Bool = false
    private var transientDoneTimer: AnyCancellable?
    private var staleCheckTimer: AnyCancellable?
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    var onActivityChanged: (@Sendable () -> Void)?

    init() {
        createDirectoryIfNeeded()
        startFileObservation()
        setupStaleWatchdog()
    }

    var activitySnapshot: AIActivitySnapshot {
        lock.withLock { _activitySnapshot }
    }

    var contextMetric: AIContextMetric? {
        lock.withLock { _contextMetric }
    }

    var sessionCostMetric: AISessionCostMetric? {
        lock.withLock { _sessionCostMetric }
    }

    var isTransientDone: Bool {
        lock.withLock { _isTransientDone }
    }

    /// Reads the current session snapshot file from disk.
    func readSessionSnapshot() {
        guard FileManager.default.fileExists(atPath: Self.sessionFileURL.path),
              let data = try? Data(contentsOf: Self.sessionFileURL) else {
            return
        }

        do {
            let msg = try JSONDecoder().decode(ClaudeBridgeMessage.self, from: data)
            let rawState = AIActivityState(rawValue: msg.activityState) ?? .idle

            let previousState = lock.withLock { self._activitySnapshot.state }

            let snapshot = AIActivitySnapshot(
                state: rawState,
                sessionID: msg.sessionID,
                model: msg.model,
                projectName: msg.projectName,
                updatedAt: Date(timeIntervalSince1970: msg.timestamp)
            )

            let context = msg.contextUsedPercent.map {
                AIContextMetric(id: "claude_context", usedPercent: $0)
            }

            let cost = msg.sessionCostUSD.map {
                AISessionCostMetric(id: "claude_cost", costUSD: $0)
            }

            lock.withLock {
                self._activitySnapshot = snapshot
                self._contextMetric = context
                self._sessionCostMetric = cost
            }

            // Handle transition to completed: briefly display Done
            if previousState == .working && rawState == .completed {
                triggerTransientDone()
            }

            onActivityChanged?()
        } catch {
            logger.debug("Failed to decode session.json: \(error.localizedDescription)")
        }
    }

    private func triggerTransientDone() {
        lock.withLock {
            self._isTransientDone = true
        }
        onActivityChanged?()

        transientDoneTimer?.cancel()
        transientDoneTimer = Just(())
            .delay(for: .seconds(3.0), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.lock.withLock {
                    self._isTransientDone = false
                }
                self.onActivityChanged?()
            }
    }

    private func setupStaleWatchdog() {
        staleCheckTimer = Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let isStale = self.lock.withLock {
                    self._activitySnapshot.isStale(timeoutSeconds: 45.0)
                }
                if isStale {
                    self.lock.withLock {
                        self._activitySnapshot = AIActivitySnapshot(
                            state: .idle,
                            sessionID: self._activitySnapshot.sessionID,
                            model: self._activitySnapshot.model,
                            projectName: self._activitySnapshot.projectName,
                            updatedAt: Date()
                        )
                    }
                    self.onActivityChanged?()
                    logger.info("Claude working state degraded to idle due to 45s inactivity")
                }
            }
    }

    private func startFileObservation() {
        let path = Self.sessionDirectoryURL.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        self.fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .link],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.readSessionSnapshot()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.fileMonitorSource = source

        // Initial read if session.json already exists
        readSessionSnapshot()
    }

    private func createDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(
            at: Self.sessionDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    deinit {
        fileMonitorSource?.cancel()
        transientDoneTimer?.cancel()
        staleCheckTimer?.cancel()
    }
}
