import Foundation

// MARK: - Plan window

struct PlanWindow: Codable {
    let usedPct: Double   // 0–100, clamped
    let resetsAt: Date
}

// MARK: - Plan usage

struct PlanUsage: Codable {
    var fiveHour: PlanWindow?
    var sevenDay: PlanWindow?
    var updatedAt: Date
}

// MARK: - Parsing + helpers (Foundation-only, no AppKit/SwiftUI)

enum ClaudePlanGauge {

    /// Parses rate_limits from a statusline payload dict. Returns nil if absent/malformed.
    static func parse(payload: [String: Any]) -> PlanUsage? {
        guard let limits = payload["rate_limits"] as? [String: Any] else { return nil }
        let fh = parseWindow(limits["five_hour"])
        let sd = parseWindow(limits["seven_day"])
        guard fh != nil || sd != nil else { return nil }
        return PlanUsage(fiveHour: fh, sevenDay: sd, updatedAt: Date())
    }

    /// Parses the answer of Claude's usage endpoint (`/api/oauth/usage`, the source of
    /// Claude Code's /usage): `five_hour` / `seven_day` with `utilization` (0–100) and an
    /// ISO 8601 `resets_at`. Same checks as the statusline payload.
    static func parseUsageResponse(_ json: [String: Any]) -> PlanUsage? {
        var limits: [String: Any] = [:]
        for key in ["five_hour", "seven_day"] {
            guard let w = json[key] as? [String: Any],
                  let pct = (w["utilization"] as? Double) ?? (w["utilization"] as? Int).map(Double.init),
                  let reset = (w["resets_at"] as? String).flatMap(isoDate) else { continue }
            limits[key] = ["used_percentage": pct, "resets_at": reset.timeIntervalSince1970]
        }
        return parse(payload: ["rate_limits": limits])
    }

    /// The access token in Claude Code's Keychain item ("Claude Code-credentials"),
    /// nil if missing or expired (Claude Code refreshes it; Coucou never does).
    static func accessToken(fromCredentials data: Data, now: Date = Date()) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        if let expiresMs = (oauth["expiresAt"] as? Double) ?? (oauth["expiresAt"] as? Int).map(Double.init),
           Date(timeIntervalSince1970: expiresMs / 1000) <= now { return nil }
        return token
    }

    /// ISO 8601 with or without fractional seconds (any number of digits).
    static func isoDate(_ string: String) -> Date? {
        let trimmed = string.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: trimmed)
    }

    private static func parseWindow(_ raw: Any?) -> PlanWindow? {
        guard let d = raw as? [String: Any] else { return nil }
        let rawPct: Double
        if let v = d["used_percentage"] as? Double { rawPct = v }
        else if let v = d["used_percentage"] as? Int { rawPct = Double(v) }
        else { return nil }
        guard rawPct >= 0, rawPct <= 200 else { return nil }
        let pct = min(100, rawPct)   // clamp 100–200 down to 100
        let rawEpoch: Double
        if let v = d["resets_at"] as? Double { rawEpoch = v }
        else if let v = d["resets_at"] as? Int { rawEpoch = Double(v) }
        else { return nil }
        guard rawEpoch > 0 else { return nil }
        // Reject if more than 400 days in the future (likely milliseconds, not seconds)
        let maxEpoch = Date().timeIntervalSince1970 + 400 * 86400
        guard rawEpoch <= maxEpoch else { return nil }
        return PlanWindow(usedPct: pct, resetsAt: Date(timeIntervalSince1970: rawEpoch))
    }

    /// Effective % for display: 0 if the reset time is in the past.
    static func effectivePct(_ w: PlanWindow) -> Double {
        w.resetsAt <= Date() ? 0 : w.usedPct
    }

    /// The higher of the two effective percentages. nil if both windows absent.
    static func dominantPct(_ usage: PlanUsage) -> Double? {
        let p1 = usage.fiveHour.map { effectivePct($0) }
        let p2 = usage.sevenDay.map { effectivePct($0) }
        switch (p1, p2) {
        case (.none, .none): return nil
        case (let x?, .none): return x
        case (.none, let y?): return y
        case (let x?, let y?): return max(x, y)
        }
    }

    /// Hex color for a given percentage (nil → grey).
    static func color(for pct: Double?) -> String {
        guard let p = pct else { return "#6B7079" }
        if p < 50  { return "#22C55E" }
        if p < 80  { return "#F59E0B" }
        return "#F4505E"
    }

    /// Label shown in the island pill chip.
    static func pillLabel(_ usage: PlanUsage?) -> String {
        guard let usage, let pct = dominantPct(usage) else { return "Claude plan" }
        return "Claude \(Int(pct.rounded()))%"
    }
}
