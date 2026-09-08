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
    private var _presentationState: AIActivityState = .idle
    private var _contextMetric: AIContextMetric?
    private var _sessionCostMetric: AISessionCostMetric?
    private var _isTransientDone: Bool = false
    private var workingStartTime: Date?
    private var dwellTimer: AnyCancellable?
    private var transientDoneTimer: AnyCancellable?
    private var staleCheckTimer: AnyCancellable?
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    var workingMinimumPresentationDuration: TimeInterval = 0.9
    var onActivityChanged: (@Sendable () -> Void)?

    init() {
        createDirectoryIfNeeded()
        startFileObservation()
        setupStaleWatchdog()
    }

    var activitySnapshot: AIActivitySnapshot {
        lock.withLock { _activitySnapshot }
    }
    var presentationState: AIActivityState {
        lock.withLock { _presentationState }
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
            logger.info("Claude hook received: \(msg.activityState, privacy: .public)")
            handleStateTransition(to: rawState)
            onActivityChanged?()
        } catch {
            logger.debug("Failed to decode session.json: \(error.localizedDescription)")
        }
    }

    private func handleStateTransition(to rawState: AIActivityState) {
        switch rawState {
        case .working:
            let shouldNotify: Bool = lock.withLock {
                if self._presentationState != .working {
                    let old = self._presentationState
                    self._presentationState = .working
                    self._isTransientDone = false
                    self.workingStartTime = Date()
                    self.dwellTimer?.cancel()
                    self.dwellTimer = nil
                    self.transientDoneTimer?.cancel()
                    self.transientDoneTimer = nil
                    logger.info("Claude state: \(old.rawValue, privacy: .public) -> working")
                    return true
                }
                return false
            }
            if shouldNotify {
                onActivityChanged?()
            }

        case .completed:
            let (currentState, elapsed) = lock.withLock { () -> (AIActivityState, TimeInterval) in
                let time = self.workingStartTime.map { Date().timeIntervalSince($0) } ?? 0
                return (self._presentationState, time)
            }
            let remainingDwell = max(0, workingMinimumPresentationDuration - elapsed)

            if currentState == .working && remainingDwell > 0 {
                dwellTimer?.cancel()
                dwellTimer = Just(())
                    .delay(for: .seconds(remainingDwell), scheduler: RunLoop.main)
                    .sink { [weak self] in
                        self?.transitionToCompleted()
                    }
            } else if currentState == .idle {
                lock.withLock {
                    self._presentationState = .working
                    self.workingStartTime = Date()
                }
                onActivityChanged?()
                dwellTimer?.cancel()
                dwellTimer = Just(())
                    .delay(for: .seconds(workingMinimumPresentationDuration), scheduler: RunLoop.main)
                    .sink { [weak self] in
                        self?.transitionToCompleted()
                    }
            } else {
                transitionToCompleted()
            }

        case .waitingForApproval:
            lock.withLock {
                self._presentationState = .waitingForApproval
                self._isTransientDone = false
                self.dwellTimer?.cancel()
                self.dwellTimer = nil
                self.transientDoneTimer?.cancel()
                self.transientDoneTimer = nil
            }
            onActivityChanged?()

        case .failed:
            lock.withLock {
                self._presentationState = .failed
                self._isTransientDone = false
                self.dwellTimer?.cancel()
                self.dwellTimer = nil
                self.transientDoneTimer?.cancel()
                self.transientDoneTimer = nil
            }
            onActivityChanged?()

        case .idle:
            let shouldReset: Bool = lock.withLock {
                if !self._isTransientDone && self.dwellTimer == nil && self._presentationState != .idle {
                    self._presentationState = .idle
                    return true
                }
                return false
            }
            if shouldReset {
                onActivityChanged?()
            }
        }
    }

    private func transitionToCompleted() {
        dwellTimer?.cancel()
        dwellTimer = nil

        lock.withLock {
            self._presentationState = .idle
            self._isTransientDone = true
        }

        let dur = PreferencesStore.sharedCompletedDisplayDuration
        logger.info("Claude state: working -> completed; transient started: \(dur, privacy: .public)s")
        onActivityChanged?()

        transientDoneTimer?.cancel()
        transientDoneTimer = Just(())
            .delay(for: .seconds(dur), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.lock.withLock {
                    self._isTransientDone = false
                    self._presentationState = .idle
                }
                logger.info("Claude state: completed -> idle")
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
