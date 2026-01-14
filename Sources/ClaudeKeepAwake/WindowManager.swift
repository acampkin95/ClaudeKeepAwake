import Cocoa
import ApplicationServices

final class WindowManager {
    private var refreshTimer: Timer?
    private let claudeMonitor: ClaudeMonitor
    
    private(set) var isFloatingEnabled = false
    private(set) var hasAccessibilityPermission = false
    
    init(claudeMonitor: ClaudeMonitor) {
        self.claudeMonitor = claudeMonitor
    }
    
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return hasAccessibilityPermission
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func enableFloating() {
        guard checkAccessibilityPermission() else {
            requestAccessibilityPermission()
            return
        }
        
        isFloatingEnabled = true
        applyFloatingToClaudeWindows()
        startRefreshTimer()
    }
    
    func disableFloating() {
        isFloatingEnabled = false
        stopRefreshTimer()
    }
    
    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.applyFloatingToClaudeWindows()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func applyFloatingToClaudeWindows() {
        guard isFloatingEnabled, let app = claudeMonitor.claudeApp else { return }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let windows = windowsRef as? [AXUIElement] else { return }
        
        for window in windows {
            setWindowLevel(window, level: CGWindowLevelForKey(.floatingWindow))
        }
    }
    
    private func setWindowLevel(_ window: AXUIElement, level: CGWindowLevel) {
        var windowIDRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, "_AXWindowID" as CFString, &windowIDRef)
        
        guard let windowID = windowIDRef as? CGWindowID else { return }
        
        _ = _CGSSetWindowLevel(CGSMainConnectionID(), windowID, level)
    }
    
    deinit {
        stopRefreshTimer()
    }
}

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> UInt32

@_silgen_name("CGSSetWindowLevel")
func _CGSSetWindowLevel(_ cid: UInt32, _ wid: CGWindowID, _ level: CGWindowLevel) -> OSStatus
