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
    private var _contextMetric: AIContextMetric?
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
            let previousState = lock.withLock { self._activitySnapshot.state }

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

            if previousState == .working && rawState == .completed {
                triggerTransientDone()
            }

            onActivityChanged?()
        } catch {
            logger.debug("Failed to decode antigravity.json: \(error.localizedDescription)")
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

        readSessionSnapshot()
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
        transientDoneTimer?.cancel()
        staleCheckTimer?.cancel()
    }
}
