import AppKit
import ApplicationServices

// MARK: - Source window in front
//
// Reads the frontmost app and, with the Accessibility permission (GitHub build), its
// window count and focused window title. The decision is in SourceFocusLogic.swift.

@MainActor
enum SourceFocus {

    /// True when the window the hook event comes from is the one in front.
    static func isInFront(payload: [String: Any]) -> Bool {
        let host = SourceFocusLogic.hostBundleId(
            bundleId: payload["bundle_id"] as? String ?? "",
            termProgram: payload["term_program"] as? String ?? "")
        guard let host, let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier?.lowercased() == host.lowercased() else { return false }
        let cwd = payload["cwd"] as? String ?? ""
        let (count, title) = windowInfo(pid: front.processIdentifier)
        return SourceFocusLogic.isSourceInFront(
            hostBundleId: host, frontmostBundleId: front.bundleIdentifier,
            windowCount: count, focusedWindowTitle: title,
            projectFolder: URL(fileURLWithPath: cwd).lastPathComponent)
    }

    /// Window count and focused window title, or nil when they can't be read.
    private static func windowInfo(pid: pid_t) -> (Int?, String?) {
        #if APPSTORE
        return (nil, nil)
        #else
        guard AXIsProcessTrusted() else { return (nil, nil) }
        let app = AXUIElementCreateApplication(pid)
        // A busy app must not stall the hook server (the default timeout is 6 s).
        AXUIElementSetMessagingTimeout(app, 0.25)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return (nil, nil) }
        var title: String?
        var windowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
           let windowRef, CFGetTypeID(windowRef) == AXUIElementGetTypeID() {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(windowRef as! AXUIElement, kAXTitleAttribute as CFString, &titleRef) == .success {
                title = titleRef as? String
            }
        }
        return (windows.count, title)
        #endif
    }
}
