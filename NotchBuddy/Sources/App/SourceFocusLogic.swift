import Foundation

// MARK: - Source window in front: pure logic
//
// When the window an agent event comes from is the one in front, the user already sees
// it: Mochi updates without sound, badge or expanding, and permission prompts and
// questions stay in that window. SourceFocus.swift reads the frontmost app and its
// focused window; this file holds the decision, so scripts/test-source-focus.sh can
// compile it on its own.

enum SourceFocusLogic {

    /// Host apps known by their TERM_PROGRAM when the hook relay sent no bundle id.
    static let termProgramBundleIds: [String: String] = [
        "vscode": "com.microsoft.VSCode",
        "apple_terminal": "com.apple.Terminal",
        "iterm.app": "com.googlecode.iterm2",
        "ghostty": "com.mitchellh.ghostty",
        "warpterminal": "dev.warp.Warp-Stable",
        "wezterm": "com.github.wez.wezterm",
    ]

    /// The bundle id of the app hosting the session: the relay's `bundle_id`
    /// (`__CFBundleIdentifier`), else the app known for its TERM_PROGRAM.
    static func hostBundleId(bundleId: String, termProgram: String) -> String? {
        let id = bundleId.trimmingCharacters(in: .whitespaces)
        if !id.isEmpty { return id }
        return termProgramBundleIds[termProgram.lowercased()]
    }

    /// True when the user is looking at the window the event comes from.
    ///
    /// - The host app must be the frontmost app.
    /// - With one window (or none readable), that is enough.
    /// - With several windows, the focused one's title must name the project folder
    ///   (VS Code and Cursor put it there). Unknown title: not sure, so not in front.
    /// - Without Accessibility (`windowCount` nil), the app being in front is enough.
    static func isSourceInFront(hostBundleId: String?, frontmostBundleId: String?,
                                windowCount: Int?, focusedWindowTitle: String?,
                                projectFolder: String) -> Bool {
        guard let host = hostBundleId?.lowercased(), !host.isEmpty,
              let front = frontmostBundleId?.lowercased(), host == front else { return false }
        guard let windowCount, windowCount > 1 else { return true }
        let folder = projectFolder.trimmingCharacters(in: .whitespaces)
        guard let title = focusedWindowTitle, !title.isEmpty, !folder.isEmpty else { return false }
        return title.range(of: folder, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
