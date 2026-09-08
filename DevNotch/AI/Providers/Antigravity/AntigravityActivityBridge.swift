import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "AntigravityBridge")

/// Observes session telemetry and hook events for Google Antigravity.
final class AntigravityActivityBridge: @unchecked Sendable {
    static let activityDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DevNotch/Activities", isDirectory: true)
    }()

    static let activityFileURL: URL = {
        activityDirectoryURL.appendingPathComponent("antigravity.json")
    }()

    private let lock = NSLock()
    private var _activitySnapshot = AIActivitySnapshot(providerID: .antigravity, state: .idle)
    private var _presentationState: AIActivityState = .idle
    private var _contextMetric: AIContextMetric?
    private var _isTransientDone: Bool = false
    private var workingStartTime: Date?
    private var dwellTask: Task<Void, Never>?
    private var transientDoneTask: Task<Void, Never>?
    private var staleCheckTimer: AnyCancellable?
    private var pollingTimer: AnyCancellable?
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var lastObservedModificationDate: Date?

    /// Minimum duration (in seconds) the UI presentation layer displays `working` state
    /// so that rapid or sub-second tasks are clearly visible to the user.
    var workingMinimumPresentationDuration: TimeInterval = 0.9

    var onActivityChanged: (@Sendable () -> Void)?

    init() {
        createDirectoryIfNeeded()
        startFileObservation()
        setupStaleWatchdog()
    }

    /// Real-time underlying activity snapshot (updated immediately on hook receipt).
    var activitySnapshot: AIActivitySnapshot {
        lock.withLock { _activitySnapshot }
    }

    /// UI presentation activity state (incorporates minimum presentation dwell policy).
    var presentationState: AIActivityState {
        lock.withLock { _presentationState }
    }

    var contextMetric: AIContextMetric? {
        lock.withLock { _contextMetric }
    }

    var isTransientDone: Bool {
        lock.withLock { _isTransientDone }
    }

    /// Reads the current antigravity activity snapshot from disk.
    func readSessionSnapshot() {
        guard FileManager.default.fileExists(atPath: Self.activityFileURL.path),
              let data = try? Data(contentsOf: Self.activityFileURL) else {
            return
        }

        do {
            let record = try JSONDecoder().decode(SanitizedActivityRecord.self, from: data)
            let rawState = AIActivityState(rawValue: record.activityState) ?? .idle

            let snapshot = AIActivitySnapshot(
                providerID: .antigravity,
                state: rawState,
                sessionID: record.sessionID,
                model: record.model,
                projectName: record.projectName,
                agentCount: record.agentCount,
                updatedAt: Date(timeIntervalSince1970: record.timestamp)
            )

            let context = record.contextUsedPercent.map {
                AIContextMetric(id: "antigravity_context", usedPercent: $0)
            }

            lock.withLock {
                self._activitySnapshot = snapshot
                self._contextMetric = context
            }

            logger.info("Antigravity hook received: \(record.activityState, privacy: .public)")
            ActivityIPCWriter.logTrace(provider: "antigravity", message: "Snapshot read: state=\(rawState.rawValue)")

            handleStateTransition(to: rawState)
            onActivityChanged?()
        } catch {
            logger.debug("Failed to decode antigravity.json: \(error.localizedDescription)")
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
                    self.dwellTask?.cancel()
                    self.dwellTask = nil
                    self.transientDoneTask?.cancel()
                    self.transientDoneTask = nil
                    logger.info("Antigravity state: \(old.rawValue, privacy: .public) -> working")
                    ActivityIPCWriter.logTrace(provider: "antigravity", message: "Antigravity state: \(old.rawValue) -> working")
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
                dwellTask?.cancel()
                dwellTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(remainingDwell * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    self?.transitionToCompleted()
                }
            } else if currentState == .idle {
                lock.withLock {
                    self._presentationState = .working
                    self.workingStartTime = Date()
                }
                logger.info("Antigravity state: idle -> working")
                ActivityIPCWriter.logTrace(provider: "antigravity", message: "Antigravity state: idle -> working")
                onActivityChanged?()

                dwellTask?.cancel()
                dwellTask = Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    let dwellTime = self.workingMinimumPresentationDuration
                    try? await Task.sleep(nanoseconds: UInt64(dwellTime * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    self.transitionToCompleted()
                }
            } else {
                transitionToCompleted()
            }

        case .waitingForApproval:
            lock.withLock {
                self._presentationState = .waitingForApproval
                self._isTransientDone = false
                self.dwellTask?.cancel()
                self.dwellTask = nil
                self.transientDoneTask?.cancel()
                self.transientDoneTask = nil
            }
            onActivityChanged?()

        case .failed:
            lock.withLock {
                self._presentationState = .failed
                self.dwellTask?.cancel()
                self.dwellTask = nil
                self.transientDoneTask?.cancel()
                self.transientDoneTask = nil
            }
            onActivityChanged?()
        case .idle:
            let shouldReset: Bool = lock.withLock {
                if !self._isTransientDone && self.dwellTask == nil && self._presentationState != .idle {
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
        dwellTask?.cancel()
        dwellTask = nil

        lock.withLock {
            self._presentationState = .idle
            self._isTransientDone = true
        }

        let dur = PreferencesStore.sharedCompletedDisplayDuration
        logger.info("Antigravity state: working -> completed")
        logger.info("Completed transient started: \(dur, privacy: .public)s")
        ActivityIPCWriter.logTrace(provider: "antigravity", message: "Antigravity state: working -> completed")
        ActivityIPCWriter.logTrace(provider: "antigravity", message: "Completed transient started: \(dur)s")

        onActivityChanged?()

        transientDoneTask?.cancel()
        transientDoneTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(dur * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finishCompletedTransient()
        }
    }

    private func finishCompletedTransient() {
        lock.withLock {
            self._isTransientDone = false
            self._presentationState = .idle
        }
        logger.info("Antigravity state: completed -> idle")
        ActivityIPCWriter.logTrace(provider: "antigravity", message: "Antigravity state: completed -> idle")
        onActivityChanged?()
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
                            providerID: .antigravity,
                            state: .idle,
                            sessionID: self._activitySnapshot.sessionID,
                            model: self._activitySnapshot.model,
                            projectName: self._activitySnapshot.projectName,
                            agentCount: self._activitySnapshot.agentCount,
                            updatedAt: Date()
                        )
                    }
                    self.onActivityChanged?()
                    logger.info("Antigravity working state degraded to idle due to 45s inactivity")
                }
            }
    }

    private func startFileObservation() {
        let path = Self.activityDirectoryURL.path
        let fd = open(path, O_EVTONLY)
        if fd >= 0 {
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
        }

        // Polling timer (250ms interval) to guarantee rapid reaction even if vnode events are coalesced
        pollingTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForFileModification()
            }

        readSessionSnapshot()
    }

    private func checkForFileModification() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: Self.activityFileURL.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return
        }
        let shouldRead: Bool = lock.withLock {
            if let last = self.lastObservedModificationDate {
                if modDate > last {
                    self.lastObservedModificationDate = modDate
                    return true
                }
                return false
            } else {
                self.lastObservedModificationDate = modDate
                return false
            }
        }
        if shouldRead {
            readSessionSnapshot()
        }
    }

    private func createDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(
            at: Self.activityDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    deinit {
        fileMonitorSource?.cancel()
        dwellTask?.cancel()
        transientDoneTask?.cancel()
        staleCheckTimer?.cancel()
        pollingTimer?.cancel()
    }
}
