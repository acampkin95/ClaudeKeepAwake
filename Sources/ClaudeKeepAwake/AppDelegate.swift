import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sleepPreventer = SleepPreventer()
    private let claudeMonitor = ClaudeMonitor()
    private lazy var windowManager = WindowManager(claudeMonitor: claudeMonitor)
    private lazy var statusBarController = StatusBarController(
        sleepPreventer: sleepPreventer,
        claudeMonitor: claudeMonitor,
        windowManager: windowManager
    )
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupClaudeMonitoring()
        statusBarController.setup()
        
        if claudeMonitor.isClaudeRunning && statusBarController.isKeepAwakeEnabled {
            _ = sleepPreventer.preventSleep()
        }
        
        statusBarController.updateStatus()
    }
    
    private func setupClaudeMonitoring() {
        claudeMonitor.onClaudeLaunched = { [weak self] in
            guard let self, self.statusBarController.isKeepAwakeEnabled else { return }
            _ = self.sleepPreventer.preventSleep()
            self.statusBarController.updateStatus()
        }
        
        claudeMonitor.onClaudeTerminated = { [weak self] in
            guard let self else { return }
            self.sleepPreventer.allowSleep()
            self.windowManager.disableFloating()
            self.statusBarController.updateStatus()
        }
        
        claudeMonitor.startMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        sleepPreventer.allowSleep()
        claudeMonitor.stopMonitoring()
    }
}
