import Foundation

@main
enum ClaudePlanGaugeTests {

    static var failures = 0

    static func check(_ label: String, _ got: String, _ expected: String) {
        if got == expected {
            print("  ✓ \(label)")
        } else {
            print("  ✗ \(label)")
            print("    got:      \(got.debugDescription)")
            print("    expected: \(expected.debugDescription)")
            failures += 1
        }
    }

    static func checkTrue(_ label: String, _ value: Bool) {
        if value { print("  ✓ \(label)") }
        else      { print("  ✗ \(label)"); failures += 1 }
    }

    static func main() {
        let futureEpoch: Double = Date().timeIntervalSince1970 + 7200  // 2 hours from now
        let pastEpoch:   Double = Date().timeIntervalSince1970 - 100   // already passed

        // ── parse ──────────────────────────────────────────────────────────────
        print("ClaudePlanGauge.parse")

        let full: [String: Any] = ["rate_limits": [
            "five_hour": ["used_percentage": 23.5, "resets_at": futureEpoch],
            "seven_day": ["used_percentage": 67.0, "resets_at": futureEpoch],
        ]]
        let usage = ClaudePlanGauge.parse(payload: full)
        checkTrue("parse full payload → non-nil",     usage != nil)
        checkTrue("five_hour usedPct 23.5",           usage?.fiveHour?.usedPct == 23.5)
        checkTrue("seven_day usedPct 67.0",           usage?.sevenDay?.usedPct == 67.0)

        // Missing rate_limits → nil
        checkTrue("missing rate_limits → nil",        ClaudePlanGauge.parse(payload: [:]) == nil)

        // Absurd pct (>200) → nil window  (150 is now clamped to 100)
        let badPct: [String: Any] = ["rate_limits": [
            "five_hour": ["used_percentage": 250.0, "resets_at": futureEpoch],
        ]]
        let badUsage = ClaudePlanGauge.parse(payload: badPct)
        checkTrue("absurd pct (250) → nil window",    badUsage?.fiveHour == nil)

        // pct 150 → clamped to 100 (not rejected)
        let clampPct: [String: Any] = ["rate_limits": [
            "five_hour": ["used_percentage": 150.0, "resets_at": futureEpoch],
        ]]
        let clampUsage = ClaudePlanGauge.parse(payload: clampPct)
        checkTrue("pct 150 → clamped to 100",         clampUsage?.fiveHour?.usedPct == 100.0)

        // pct 201 → rejected
        let tooBig: [String: Any] = ["rate_limits": [
            "five_hour": ["used_percentage": 201.0, "resets_at": futureEpoch],
        ]]
        checkTrue("pct 201 → nil window",             ClaudePlanGauge.parse(payload: tooBig)?.fiveHour == nil)

        // resets_at > 400 days → rejected
        let farFuture = Date().timeIntervalSince1970 + 401 * 86400
        let msEpoch: [String: Any] = ["rate_limits": [
            "five_hour": ["used_percentage": 50.0, "resets_at": farFuture],
        ]]
        checkTrue("resets_at > 400d → nil window",    ClaudePlanGauge.parse(payload: msEpoch)?.fiveHour == nil)

        // Negative pct → nil window
        let negPct: [String: Any] = ["rate_limits": [
            "five_hour": ["used_percentage": -5.0, "resets_at": futureEpoch],
        ]]
        checkTrue("negative pct → nil window",        ClaudePlanGauge.parse(payload: negPct)?.fiveHour == nil)

        // Int pct accepted
        let intPct: [String: Any] = ["rate_limits": [
            "five_hour": ["used_percentage": 42, "resets_at": Int(futureEpoch)],
        ]]
        let intUsage = ClaudePlanGauge.parse(payload: intPct)
        checkTrue("Int pct parsed",                   intUsage?.fiveHour?.usedPct == 42.0)

        // ── effectivePct (expired window) ─────────────────────────────────────
        print("ClaudePlanGauge.effectivePct")

        let expiredWindow = PlanWindow(usedPct: 80, resetsAt: Date(timeIntervalSince1970: pastEpoch))
        let futureWindow  = PlanWindow(usedPct: 80, resetsAt: Date(timeIntervalSince1970: futureEpoch))
        checkTrue("expired window → 0",               ClaudePlanGauge.effectivePct(expiredWindow) == 0)
        checkTrue("future window → original pct",     ClaudePlanGauge.effectivePct(futureWindow)  == 80)

        // ── dominantPct ────────────────────────────────────────────────────────
        print("ClaudePlanGauge.dominantPct")

        let both  = PlanUsage(fiveHour: PlanWindow(usedPct: 30, resetsAt: Date(timeIntervalSince1970: futureEpoch)),
                              sevenDay: PlanWindow(usedPct: 70, resetsAt: Date(timeIntervalSince1970: futureEpoch)),
                              updatedAt: Date())
        let fhOnly = PlanUsage(fiveHour: PlanWindow(usedPct: 55, resetsAt: Date(timeIntervalSince1970: futureEpoch)),
                               sevenDay: nil, updatedAt: Date())
        let empty  = PlanUsage(fiveHour: nil, sevenDay: nil, updatedAt: Date())

        checkTrue("dominant picks higher (70)",       ClaudePlanGauge.dominantPct(both) == 70)
        checkTrue("dominant with one window (55)",    ClaudePlanGauge.dominantPct(fhOnly) == 55)
        checkTrue("dominant with no windows → nil",   ClaudePlanGauge.dominantPct(empty) == nil)

        // ── color ──────────────────────────────────────────────────────────────
        print("ClaudePlanGauge.color")

        check("nil → grey",    ClaudePlanGauge.color(for: nil),  "#6B7079")
        check("0 → green",     ClaudePlanGauge.color(for: 0),    "#22C55E")
        check("49 → green",    ClaudePlanGauge.color(for: 49),   "#22C55E")
        check("50 → orange",   ClaudePlanGauge.color(for: 50),   "#F59E0B")
        check("79 → orange",   ClaudePlanGauge.color(for: 79),   "#F59E0B")
        check("80 → red",      ClaudePlanGauge.color(for: 80),   "#F4505E")
        check("100 → red",     ClaudePlanGauge.color(for: 100),  "#F4505E")

        // ── pillLabel ──────────────────────────────────────────────────────────
        print("ClaudePlanGauge.pillLabel")

        check("nil usage → 'Claude plan'",             ClaudePlanGauge.pillLabel(nil),    "Claude plan")
        check("no windows → 'Claude plan'",            ClaudePlanGauge.pillLabel(empty),  "Claude plan")
        check("70 pct → 'Claude 70%'",                 ClaudePlanGauge.pillLabel(both),   "Claude 70%")
        check("55 pct → 'Claude 55%'",                 ClaudePlanGauge.pillLabel(fhOnly), "Claude 55%")

        // ── usage endpoint ─────────────────────────────────────────────────────
        print("ClaudePlanGauge.parseUsageResponse")

        let isoFormatter = ISO8601DateFormatter()
        let futureISO = isoFormatter.string(from: Date(timeIntervalSince1970: futureEpoch))
            .replacingOccurrences(of: "Z", with: ".442477+00:00")
        let api: [String: Any] = [
            "five_hour": ["utilization": 39.0, "resets_at": futureISO, "limit_dollars": NSNull()],
            "seven_day": ["utilization": 61, "resets_at": futureISO],
            "seven_day_opus": NSNull(),
        ]
        let apiUsage = ClaudePlanGauge.parseUsageResponse(api)
        checkTrue("usage response → five_hour 39",          apiUsage?.fiveHour?.usedPct == 39.0)
        checkTrue("usage response → seven_day 61 (Int)",     apiUsage?.sevenDay?.usedPct == 61.0)
        checkTrue("microsecond resets_at parsed",
                  abs((apiUsage?.fiveHour?.resetsAt.timeIntervalSince1970 ?? 0) - futureEpoch.rounded(.down)) < 1)
        checkTrue("seven_day only → five_hour nil",
                  ClaudePlanGauge.parseUsageResponse(["five_hour": NSNull(),
                                                      "seven_day": ["utilization": 5.0, "resets_at": futureISO]])?.fiveHour == nil)
        checkTrue("empty response → nil",                    ClaudePlanGauge.parseUsageResponse([:]) == nil)
        checkTrue("bad date → nil",
                  ClaudePlanGauge.parseUsageResponse(["five_hour": ["utilization": 5.0, "resets_at": "soon"]]) == nil)
        checkTrue("ISO without fraction",                    ClaudePlanGauge.isoDate("2026-10-12T19:00:00+00:00") != nil)

        // ── credentials ────────────────────────────────────────────────────────
        print("ClaudePlanGauge.accessToken")

        func creds(_ oauth: [String: Any]) -> Data {
            try! JSONSerialization.data(withJSONObject: ["claudeAiOauth": oauth, "mcpOAuth": [:]])
        }
        let nowMs = Date().timeIntervalSince1970 * 1000
        check("valid token",
              ClaudePlanGauge.accessToken(fromCredentials: creds(["accessToken": "tok", "expiresAt": nowMs + 60_000])) ?? "nil", "tok")
        check("expired token → nil",
              ClaudePlanGauge.accessToken(fromCredentials: creds(["accessToken": "tok", "expiresAt": nowMs - 1])) ?? "nil", "nil")
        check("no expiry → token",
              ClaudePlanGauge.accessToken(fromCredentials: creds(["accessToken": "tok"])) ?? "nil", "tok")
        check("empty token → nil",
              ClaudePlanGauge.accessToken(fromCredentials: creds(["accessToken": ""])) ?? "nil", "nil")
        check("not JSON → nil",
              ClaudePlanGauge.accessToken(fromCredentials: Data("nope".utf8)) ?? "nil", "nil")

        // ── finish ─────────────────────────────────────────────────────────────
        if failures == 0 {
            print("\nAll tests passed.")
            exit(0)
        } else {
            print("\n\(failures) test(s) failed.")
            exit(1)
        }
    }
}
