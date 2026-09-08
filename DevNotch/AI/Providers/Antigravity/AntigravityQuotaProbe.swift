import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "AntigravityQuotaProbe")

private final class LocalhostTrustDelegate: NSObject, URLSessionDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.host == "127.0.0.1" || challenge.protectionSpace.host == "localhost" {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

/// Discovers active Antigravity LanguageServerService ports and fetches user quota summaries.
struct AntigravityQuotaProbe: Sendable {
    private static let sessionDelegate = LocalhostTrustDelegate()

    /// Discovers listening TCP ports for running `agy` / `language_server` processes.
    static func discoverListeningPorts() -> [Int] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-a", "-c", "agy"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var ports: [Int] = []
            for line in output.components(separatedBy: .newlines) {
                if let colonRange = line.range(of: ":", options: .backwards),
                   let spaceRange = line.range(of: " ", range: colonRange.upperBound..<line.endIndex) {
                    let portStr = String(line[colonRange.upperBound..<spaceRange.lowerBound])
                    if let port = Int(portStr), port > 1024, !ports.contains(port) {
                        ports.append(port)
                    }
                }
            }
            return ports
        } catch {
            return []
        }
    }

    /// Fetches the live quota summary from the local LanguageServerService if available.
    static func fetchQuotaSummary() async -> AIUsage? {
        let ports = discoverListeningPorts()
        guard !ports.isEmpty else { return nil }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
        let session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)

        for port in ports {
            guard let url = URL(string: "https://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary") else {
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: String] = [
                "ideName": "antigravity",
                "extensionName": "antigravity",
                "locale": "en",
                "ideVersion": "unknown"
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (data, response) = try await session.data(for: request)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    if let usage = parseQuotaSummary(data: data) {
                        logger.info("Retrieved live Antigravity quota summary with \(usage.windows.count) windows")
                        return usage
                    }
                }
            } catch {
                continue
            }
        }

        return nil
    }

    static func parseQuotaSummary(data: Data, now: Date = Date()) -> AIUsage? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resp = json["response"] as? [String: Any],
              let groups = resp["groups"] as? [[String: Any]] else {
            return nil
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stdFormatter = ISO8601DateFormatter()

        var windows: [AIUsageWindow] = []

        for group in groups {
            let groupName = (group["displayName"] as? String) ?? ""
            if groupName.localizedCaseInsensitiveContains("gemini") || groupName.isEmpty {
                if let buckets = group["buckets"] as? [[String: Any]] {
                    for bucket in buckets {
                        let bucketId = (bucket["bucketId"] as? String) ?? ""
                        let displayName = (bucket["displayName"] as? String) ?? ""
                        let remainingFraction = (bucket["remainingFraction"] as? Double) ?? 1.0
                        let usedPercent = max(0.0, min(100.0, (1.0 - remainingFraction) * 100.0))

                        var resetDate: Date? = nil
                        if let resetStr = bucket["resetTime"] as? String {
                            resetDate = isoFormatter.date(from: resetStr) ?? stdFormatter.date(from: resetStr)
                        }

                        let windowId: String
                        let label: String
                        let durationMinutes: Int
                        if bucketId.contains("5h") || displayName.localizedCaseInsensitiveContains("five hour") {
                            windowId = "5h"
                            label = "5-Hour Limit"
                            durationMinutes = 300
                        } else if bucketId.contains("weekly") || displayName.localizedCaseInsensitiveContains("weekly") {
                            windowId = "weekly"
                            label = "Weekly Limit"
                            durationMinutes = 10080
                        } else {
                            windowId = bucketId
                            label = displayName.isEmpty ? bucketId : displayName
                            durationMinutes = 10080
                        }

                        windows.append(AIUsageWindow(
                            id: windowId,
                            label: label,
                            durationMinutes: durationMinutes,
                            usedPercent: usedPercent,
                            resetsAt: resetDate
                        ))
                    }
                }
            }
        }

        guard !windows.isEmpty else { return nil }
        return AIUsage(windows: windows, updatedAt: now)
    }
}
