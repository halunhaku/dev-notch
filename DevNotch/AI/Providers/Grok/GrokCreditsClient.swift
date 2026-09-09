import Foundation
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "GrokCredits")

struct GrokCreditsSnapshot: Equatable, Sendable {
    let usedPercent: Double?
    let resetsAt: Date?
    let durationMinutes: Int
    let label: String
    let subscriptionTier: String?
}

enum GrokCreditsError: Error, Equatable {
    case unauthorized
    case requestFailed(Int)
    case parseFailed
}

/// Fetches SuperGrok credit usage via the Grok CLI-proxy REST API.
/// Uses the local `grok login` bearer; does not read browser cookies.
enum GrokCreditsClient {
    static let billingURL = URL(string: "https://cli-chat-proxy.grok.com/v1/billing?format=credits")!
    static let settingsURL = URL(string: "https://cli-chat-proxy.grok.com/v1/settings")!

    static func fetch(accessToken: String) async throws -> GrokCreditsSnapshot {
        var request = URLRequest(url: billingURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("xai-grok-cli", forHTTPHeaderField: "x-xai-token-auth")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DevNotch", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 {
            throw GrokCreditsError.unauthorized
        }
        guard status == 200 else {
            logger.error("Grok credits request failed: HTTP \(status)")
            throw GrokCreditsError.requestFailed(status)
        }

        var snapshot = try parseSnapshot(data)
        if let tier = await fetchSubscriptionTier(accessToken: accessToken) {
            snapshot = GrokCreditsSnapshot(
                usedPercent: snapshot.usedPercent,
                resetsAt: snapshot.resetsAt,
                durationMinutes: snapshot.durationMinutes,
                label: snapshot.label,
                subscriptionTier: tier
            )
        }
        return snapshot
    }

    static func parseSnapshot(_ data: Data) throws -> GrokCreditsSnapshot {
        let decoded: CreditsResponse
        do {
            decoded = try JSONDecoder().decode(CreditsResponse.self, from: data)
        } catch {
            throw GrokCreditsError.parseFailed
        }
        guard let config = decoded.config else {
            throw GrokCreditsError.parseFailed
        }

        let resetsAt = GrokISO8601.parse(config.currentPeriod?.end)
            ?? GrokISO8601.parse(config.billingPeriodEnd)
        let durationMinutes = durationMinutes(
            periodType: config.currentPeriod?.type,
            start: GrokISO8601.parse(config.currentPeriod?.start) ?? GrokISO8601.parse(config.billingPeriodStart),
            end: resetsAt
        )
        let label = label(for: durationMinutes, periodType: config.currentPeriod?.type)

        let usedPercent: Double?
        if let percent = config.creditUsagePercent, percent.isFinite {
            usedPercent = min(100, max(0, percent))
        } else if let cap = config.onDemandCap?.val, cap > 0, let used = config.onDemandUsed?.val {
            usedPercent = min(100, max(0, used / cap * 100))
        } else if let product = config.productUsage?.first(where: { $0.usagePercent != nil })?.usagePercent {
            usedPercent = min(100, max(0, product))
        } else {
            usedPercent = nil
        }

        return GrokCreditsSnapshot(
            usedPercent: usedPercent,
            resetsAt: resetsAt,
            durationMinutes: durationMinutes,
            label: label,
            subscriptionTier: config.subscriptionTier ?? decoded.subscriptionTier
        )
    }

    private static func fetchSubscriptionTier(accessToken: String) async -> String? {
        var request = URLRequest(url: settingsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 2
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("xai-grok-cli", forHTTPHeaderField: "x-xai-token-auth")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DevNotch", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let settings = try JSONDecoder().decode(SettingsResponse.self, from: data)
            let tier = settings.subscriptionTierDisplay?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (tier?.isEmpty == false) ? tier : nil
        } catch {
            return nil
        }
    }

    private static func durationMinutes(periodType: String?, start: Date?, end: Date?) -> Int {
        if let periodType {
            if periodType.localizedCaseInsensitiveContains("WEEKLY") { return 10_080 }
            if periodType.localizedCaseInsensitiveContains("MONTHLY") { return 43_200 }
        }
        if let start, let end {
            let minutes = Int(end.timeIntervalSince(start) / 60)
            if minutes > 0 { return minutes }
        }
        return 10_080
    }

    private static func label(for durationMinutes: Int, periodType: String?) -> String {
        if let periodType {
            if periodType.localizedCaseInsensitiveContains("WEEKLY") { return "Weekly" }
            if periodType.localizedCaseInsensitiveContains("MONTHLY") { return "Monthly" }
        }
        return AIUsageWindow.defaultLabel(for: durationMinutes)
    }

    private struct CreditsResponse: Decodable {
        let config: CreditsConfig?
        let subscriptionTier: String?
    }

    private struct CreditsConfig: Decodable {
        let creditUsagePercent: Double?
        let currentPeriod: CurrentPeriod?
        let billingPeriodStart: String?
        let billingPeriodEnd: String?
        let onDemandCap: CreditsAmount?
        let onDemandUsed: CreditsAmount?
        let subscriptionTier: String?
        let productUsage: [ProductUsage]?
    }

    private struct CurrentPeriod: Decodable {
        let type: String?
        let start: String?
        let end: String?
    }

    private struct CreditsAmount: Decodable {
        let val: Double?
    }

    private struct ProductUsage: Decodable {
        let product: String?
        let usagePercent: Double?
    }

    private struct SettingsResponse: Decodable {
        let subscriptionTierDisplay: String?

        enum CodingKeys: String, CodingKey {
            case subscriptionTierDisplay = "subscription_tier_display"
        }
    }
}

enum GrokISO8601 {
    static func parse(_ raw: String?) -> Date? {
        guard var raw, !raw.isEmpty else { return nil }
        if raw.hasSuffix("+00:00") {
            raw = String(raw.dropLast(6)) + "Z"
        }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: raw) {
            return date
        }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: raw)
    }
}
