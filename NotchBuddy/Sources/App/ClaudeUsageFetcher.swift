#if !APPSTORE
import Foundation

// MARK: - Claude plan usage from Claude's usage endpoint
//
// The statusline only reports limits from Claude Code in a terminal; the Claude app's
// Code tab never runs it. So when the Claude plan pill shows, Coucou also asks Claude's
// usage endpoint (the source of Claude Code's /usage) with the token Claude Code keeps in
// the Keychain. The token is read through /usr/bin/security, which the item already
// trusts (Claude Code reads it that way), so macOS asks nothing. It is never stored,
// logged or refreshed by Coucou, and goes only to api.anthropic.com.

enum ClaudeUsageFetcher {

    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    /// nil if Claude Code is not signed in, its token expired, or the request failed.
    static func fetch() async -> PlanUsage? {
        guard let credentials = await Task.detached(operation: readCredentials).value,
              let token = ClaudePlanGauge.accessToken(fromCredentials: credentials) else { return nil }
        var request = URLRequest(url: endpoint, timeoutInterval: 10)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        guard let (body, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return nil }
        return ClaudePlanGauge.parseUsageResponse(json)
    }

    private static func readCredentials() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}
#endif
