import Cocoa

final class ClaudeMonitor {
    private static let claudeBundleID = "com.anthropic.claudefordesktop"
    
    var onClaudeLaunched: (() -> Void)?
    var onClaudeTerminated: (() -> Void)?
    
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    
    var isClaudeRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.claudeBundleID).first != nil
    }
    
    var claudeApp: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.claudeBundleID).first
    }
    
    func startMonitoring() {
        let workspace = NSWorkspace.shared
        let center = workspace.notificationCenter
        
        launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == Self.claudeBundleID else { return }
            self?.onClaudeLaunched?()
        }
        
        terminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == Self.claudeBundleID else { return }
            self?.onClaudeTerminated?()
        }
    }
    
    func stopMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        if let observer = launchObserver {
            center.removeObserver(observer)
        }
        if let observer = terminateObserver {
            center.removeObserver(observer)
        }
        launchObserver = nil
        terminateObserver = nil
    }
    
    deinit {
        stopMonitoring()
    }
}
