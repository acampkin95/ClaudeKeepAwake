import Cocoa

final class StatusBarController {
    private var statusItem: NSStatusItem?
    private let sleepPreventer: SleepPreventer
    private let claudeMonitor: ClaudeMonitor
    private let windowManager: WindowManager
    
    private var isEnabled = true
    private var enabledMenuItem: NSMenuItem?
    private var floatingMenuItem: NSMenuItem?
    private var statusMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    
    init(sleepPreventer: SleepPreventer, claudeMonitor: ClaudeMonitor, windowManager: WindowManager) {
        self.sleepPreventer = sleepPreventer
        self.claudeMonitor = claudeMonitor
        self.windowManager = windowManager
    }
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "Claude Keep Awake")
        
        let menu = NSMenu()
        
        statusMenuItem = NSMenuItem(title: "Claude: Not Running", action: nil, keyEquivalent: "")
        statusMenuItem?.isEnabled = false
        menu.addItem(statusMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        enabledMenuItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        enabledMenuItem?.target = self
        enabledMenuItem?.state = .on
        menu.addItem(enabledMenuItem!)
        
        floatingMenuItem = NSMenuItem(title: "Float Windows", action: #selector(toggleFloating), keyEquivalent: "f")
        floatingMenuItem?.target = self
        floatingMenuItem?.state = .off
        menu.addItem(floatingMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        launchAtLoginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginMenuItem?.target = self
        launchAtLoginMenuItem?.state = LaunchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchAtLoginMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        updateStatus()
    }
    
    func updateStatus() {
        let isRunning = claudeMonitor.isClaudeRunning
        let isPreventing = sleepPreventer.isPreventingSleep
        
        if isRunning && isEnabled {
            statusMenuItem?.title = isPreventing ? "Claude: Active (No Sleep)" : "Claude: Active"
            statusItem?.button?.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Keeping Awake")
        } else if isRunning {
            statusMenuItem?.title = "Claude: Running (Disabled)"
            statusItem?.button?.image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "Disabled")
        } else {
            statusMenuItem?.title = "Claude: Not Running"
            statusItem?.button?.image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "Claude Not Running")
        }
        
        floatingMenuItem?.state = windowManager.isFloatingEnabled ? .on : .off
    }
    
    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enabledMenuItem?.state = isEnabled ? .on : .off
        
        if isEnabled && claudeMonitor.isClaudeRunning {
            _ = sleepPreventer.preventSleep()
        } else {
            sleepPreventer.allowSleep()
        }
        
        updateStatus()
    }
    
    @objc private func toggleFloating() {
        if windowManager.isFloatingEnabled {
            windowManager.disableFloating()
        } else {
            windowManager.enableFloating()
        }
        updateStatus()
    }
    
    @objc private func toggleLaunchAtLogin() {
        let newState = !LaunchAtLoginManager.isEnabled
        LaunchAtLoginManager.isEnabled = newState
        launchAtLoginMenuItem?.state = newState ? .on : .off
    }
    
    @objc private func quit() {
        sleepPreventer.allowSleep()
        NSApp.terminate(nil)
    }
    
    var isKeepAwakeEnabled: Bool { isEnabled }
}
