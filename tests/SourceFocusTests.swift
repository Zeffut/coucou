import Foundation

@main
enum SourceFocusTests {
    static func main() {
        testHostBundleId()
        testInFront()
        print("SourceFocusLogic: all cases passed")
    }

    static func testHostBundleId() {
        precondition(SourceFocusLogic.hostBundleId(bundleId: "com.anthropic.claudefordesktop", termProgram: "")
                     == "com.anthropic.claudefordesktop", "bundle id wins")
        precondition(SourceFocusLogic.hostBundleId(bundleId: "com.microsoft.VSCode", termProgram: "Apple_Terminal")
                     == "com.microsoft.VSCode", "bundle id wins over TERM_PROGRAM")
        precondition(SourceFocusLogic.hostBundleId(bundleId: "", termProgram: "Apple_Terminal")
                     == "com.apple.Terminal", "Terminal from TERM_PROGRAM")
        precondition(SourceFocusLogic.hostBundleId(bundleId: "", termProgram: "vscode")
                     == "com.microsoft.VSCode", "VS Code from TERM_PROGRAM")
        precondition(SourceFocusLogic.hostBundleId(bundleId: "  ", termProgram: "unknown") == nil, "unknown host")
    }

    static func testInFront() {
        func check(_ host: String?, _ front: String?, _ count: Int?, _ title: String?, _ folder: String) -> Bool {
            SourceFocusLogic.isSourceInFront(hostBundleId: host, frontmostBundleId: front,
                                             windowCount: count, focusedWindowTitle: title,
                                             projectFolder: folder)
        }
        let vscode = "com.microsoft.VSCode"
        // Another app in front: notify.
        precondition(!check(vscode, "com.apple.Safari", 1, "x", "coucou"), "other app in front")
        precondition(!check(nil, vscode, 1, nil, "coucou"), "unknown host")
        precondition(!check(vscode, nil, 1, nil, "coucou"), "no frontmost app")
        // The host app in front with a single window, or no Accessibility: quiet.
        precondition(check(vscode, "com.microsoft.vscode", 1, nil, "coucou"), "bundle ids compare without case")
        precondition(check(vscode, vscode, nil, nil, "coucou"), "no Accessibility: app in front is enough")
        precondition(check(vscode, vscode, 0, nil, "coucou"), "no window list")
        // Several windows: the focused one must name the project.
        precondition(check(vscode, vscode, 3, "HookServer.swift — coucou", "coucou"), "project window in front")
        precondition(check(vscode, vscode, 3, "README.md — Coucou", "coucou"), "title match ignores case")
        precondition(!check(vscode, vscode, 3, "index.ts — jarvis", "coucou"), "another project's window")
        precondition(!check(vscode, vscode, 3, nil, "coucou"), "unreadable title: notify")
        precondition(!check(vscode, vscode, 3, "", "coucou"), "empty title: notify")
        precondition(!check(vscode, vscode, 3, "anything", ""), "no project folder: notify")
    }
}
