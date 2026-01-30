# ClaudeKeepAwake - Agent Codebase Index

## Project Overview

**ClaudeKeepAwake** is a macOS menubar utility that automatically prevents system sleep when Claude Desktop is running. It monitors Claude.app lifecycle and manages power assertions to keep the Mac awake during AI interactions.

**Language:** Swift 5.9+
**Platform:** macOS 13.0+
**Architecture:** Event-driven, single-threaded (main thread), Cocoa-based

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     NSApplication (Accessory)                │
├─────────────────────────────────────────────────────────────┤
│                       AppDelegate                            │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  applicationDidFinishLaunching()                        ││
│  │    ├─> setupClaudeMonitoring()                          ││
│  │    └─> statusBarController.setup()                      ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ClaudeMonitor  │  │SleepPreventer│  │StatusBarController│ │
│  │               │  │              │  │                  │  │
│  │ NSWorkspace   │──│ IOKit.pwr_mgt│──│ NSStatusBar     │  │
│  │ Notifications │  │ Assertions   │  │ NSMenu          │  │
│  └───────────────┘  └──────────────┘  └─────────────────┘  │
│                                                   │          │
│  ┌───────────────────────────────────────────────┘          │
│  │ WindowManager (AXUIElement + CGSPrivate)                 │
│  └──────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. **Entry Point**
- **File:** `Sources/ClaudeKeepAwake/main.swift`
- **Purpose:** Application bootstrap, sets accessory policy (no dock icon)
- **Key:** `app.setActivationPolicy(.accessory)` - menubar-only app

### 2. **AppDelegate** (Central Coordinator)
- **File:** `Sources/ClaudeKeepAwake/AppDelegate.swift`
- **Responsibilities:**
  - Initializes all subsystems
  - Wires monitoring callbacks to sleep prevention
  - Coordinates cleanup on termination
- **Critical Flow:**
  ```swift
  Claude launches → onClaudeLaunched → preventSleep() → updateStatus()
  Claude quits → onClaudeTerminated → allowSleep() → updateStatus()
  ```

### 3. **ClaudeMonitor** (Lifecycle Observer)
- **File:** `Sources/ClaudeKeepAwake/ClaudeMonitor.swift`
- **Bundle ID:** `com.anthropic.claudefordesktop`
- **API:** NSWorkspace notifications
  - `NSWorkspace.didLaunchApplicationNotification`
  - `NSWorkspace.didTerminateApplicationNotification`
- **State:** `isClaudeRunning: Bool`, `claudeApp: NSRunningApplication?`
- **Thread Safety:** Main queue (`queue: .main`)

### 4. **SleepPreventer** (Power Management)
- **File:** `Sources/ClaudeKeepAwake/SleepPreventer.swift`
- **Framework:** IOKit.pwr_mgt
- **Assertion Type:** `kIOPMAssertionTypeNoDisplaySleep`
- **Assertion Reason:** "ClaudeKeepAwake: Keeping system awake for Claude.app"
- **State Management:** `assertionID: IOPMAssertionID`, `isPreventingSleep: Bool`
- **Cleanup:** Automatic in `deinit` (defensive)

### 5. **StatusBarController** (UI Layer)
- **File:** `Sources/ClaudeKeepAwake/StatusBarController.swift`
- **Menu Structure:**
  ```
  Status: "Claude: Active (No Sleep)" [disabled]
  ──────────────────────────────────────
  ✓ Enabled (Cmd+E)
  ✓ Float Windows (Cmd+F)
  ──────────────────────────────────────
  ✓ Launch at Login
  ──────────────────────────────────────
  Quit (Cmd+Q)
  ```
- **Icons:** SF Symbols
  - Inactive: `moon.zzz`
  - Active: `sun.max.fill`
- **State:** `isEnabled: Bool` (user toggle for keep-awake feature)

### 6. **WindowManager** (Window Level Manipulator)
- **File:** `Sources/ClaudeKeepAwake/WindowManager.swift`
- **Purpose:** Makes Claude windows float above all others (optional feature)
- **Frameworks:**
  - `ApplicationServices` (AXUIElement)
  - Private: `CGSSetWindowLevel` (via `@_silgen_name`)
- **Permission:** Requires Accessibility (AX) permission
  - `AXIsProcessTrustedWithOptions()` - check
  - `kAXTrustedCheckOptionPrompt: true` - prompt user
- **Refresh Rate:** 2.0 second Timer
- **Window Level:** `.floatingWindow` (keeps Claude on top)

### 7. **LaunchAtLoginManager** (Login Item Helper)
- **File:** `Sources/ClaudeKeepAwake/LaunchAtLoginManager.swift`
- **Framework:** ServiceManagement
- **API:** `SMAppService.mainApp` (macOS 13+)
- **Fallback:** `UserDefaults` for older macOS versions
- **Bundle ID:** `com.local.ClaudeKeepAwake`

---

## Data Flow

### Startup Sequence
```
1. main.swift → NSApplication.shared.run()
2. AppDelegate.applicationDidFinishLaunching()
3. setupClaudeMonitoring()
   └─> Register NSWorkspace observers
4. statusBarController.setup()
   └─> Create NSStatusItem + NSMenu
5. Check Claude running state
   └─> If yes + enabled → preventSleep()
6. updateStatus() → Initial UI state
```

### Claude Launch Event
```
NSWorkspace.didLaunchApplicationNotification
    ↓
ClaudeMonitor.onClaudeLaunched (callback)
    ↓
AppDelegate closure captures [weak self]
    ↓
if statusBarController.isKeepAwakeEnabled:
    sleepPreventer.preventSleep()
    ↓
statusBarController.updateStatus()
    ↓
UI: "Claude: Active (No Sleep)" + sun.max.fill icon
```

### Claude Terminate Event
```
NSWorkspace.didTerminateApplicationNotification
    ↓
ClaudeMonitor.onClaudeTerminated (callback)
    ↓
sleepPreventer.allowSleep()
    ↓
windowManager.disableFloating() (if enabled)
    ↓
statusBarController.updateStatus()
    ↓
UI: "Claude: Not Running" + moon.zzz icon
```

### User Toggle Events
```
User clicks "Enabled" menu item
    ↓
@objc toggleEnabled()
    ↓
isEnabled.toggle()
    ↓
if enabled + Claude running:
    preventSleep()
  else:
    allowSleep()
    ↓
updateStatus()
```

---

## Key Patterns & Conventions

### Memory Management
- **Weak capture:** All closures use `[weak self]` to prevent retain cycles
- **Deinit cleanup:** All managers clean up resources (observers, timers, assertions)
- **Lazy initialization:** `windowManager` and `statusBarController` are `lazy`

### Threading
- **Main thread only:** All UI and monitoring runs on `.main` queue
- **Timer:** `Timer.scheduledTimer` runs on main thread RunLoop

### Error Handling
- **Silent failures:** Most errors are logged but don't crash
- **Guard statements:** Early returns for invalid states
- **Assertion release:** Defensive cleanup even if assertion wasn't created

### State Exposure
- **Read-only properties:** `isPreventingSleep`, `isClaudeRunning`, `isFloatingEnabled`
- **Computed properties:** `isKeepAwakeEnabled` in StatusBarController
- **No state sharing:** Each component owns its state; coordination via callbacks

---

## External Dependencies

### System Frameworks
- `Cocoa` - NSApplication, NSWorkspace, NSStatusBar, NSRunningApplication
- `IOKit.pwr_mgt` - Power assertion management
- `ApplicationServices` - Accessibility API (AXUIElement)
- `ServiceManagement` - Login item management

### Private APIs
```swift
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> UInt32

@_silgen_name("CGSSetWindowLevel")
func _CGSSetWindowLevel(_ cid: UInt32, _ wid: CGWindowID, _ level: CGWindowLevel) -> OSStatus
```
**Note:** These are undocumented Core Graphics Services APIs used for window level manipulation. May break on macOS updates.

---

## Build Configuration

### Package.swift
- **Swift Tools Version:** 5.9
- **Minimum macOS:** 13.0
- **Target:** Executable `ClaudeKeepAwake`
- **Linker Settings:**
  - `-framework Cocoa`
  - `-framework IOKit`
  - `-framework ApplicationServices`
  - `-framework ServiceManagement`

### Build Commands
```bash
swift build              # Debug build
swift build -c release   # Release build
./build.sh               # Custom build script
```

---

## Testing Considerations

### Manual Testing Checklist
- [ ] Claude.app launch → Sleep prevention activates
- [ ] Claude.app quit → Sleep prevention releases
- [ ] Toggle "Enabled" → Sleep starts/stops immediately
- [ ] Toggle "Float Windows" → Claude windows stay on top (requires Accessibility permission)
- [ ] Toggle "Launch at Login" → SMAppService registers/unregisters
- [ ] System sleep → Prevented when Claude + enabled

### Edge Cases
- Claude quits while sleep is prevented → Cleanup in `allowSleep()`
- App terminates while monitoring → `applicationWillTerminate` cleanup
- Accessibility permission denied → WindowManager prompts user
- Multiple Claude instances → Only first instance tracked (`runningApplications.first`)

---

## Security & Permissions

### Required Entitlements
1. **Accessibility** (for WindowManager)
   - Prompt: System Settings → Privacy & Security → Accessibility
   - Runtime check: `AXIsProcessTrustedWithOptions()`
   - User can deny gracefully (feature just won't work)

2. **No sandbox** (not a sandboxed app)
   - Requires system-wide access to:
     - NSWorkspace notifications
     - IOPMAssertion (power management)
     - Other app windows (AXUIElement)

---

## Known Limitations

1. **Bundle ID hardcoded:** `com.anthropic.claudefordesktop` - breaks if Anthropic changes it
2. **Private API usage:** `CGSSetWindowLevel` may break on macOS updates
3. **No settings UI:** Preferences stored in code only
4. **No crash reporting:** Silent failures only
5. **No auto-update mechanism:** Manual updates required
6. **Single app focus:** Only monitors Claude, not other AI apps

---

## Future Enhancement Ideas

- [ ] Settings panel (customizable assertion reason, refresh rate)
- [ ] Multiple app support (ChatGPT, Cursor, etc.)
- [ ] Notification on sleep prevention state change
- [ ] Statistics dashboard (time prevented, energy impact)
- [ ] Hotkey support (Cmd+Shift+K to toggle)
- [ ] Auto-update framework (Sparkle)
- [ ] Crash reporting (Sentry)
- [ ] Localization (non-English locales)

---

## Maintenance Notes

### Codebase Size
- **Files:** 7 Swift files
- **Lines:** ~400 total
- **Complexity:** Low (straightforward Cocoa app)

### Key Files to Modify When:
| Change | Files to Edit |
|--------|---------------|
| Add new app to monitor | `ClaudeMonitor.swift` (add bundle ID constants) |
| Change assertion behavior | `SleepPreventer.swift` (assertion type/reason) |
| Modify menu structure | `StatusBarController.swift` (menu items) |
| Adjust window floating | `WindowManager.swift` (refresh rate, window level) |
| Update icons/symbols | `StatusBarController.swift` (SF Symbol names) |

---

**Last Updated:** 2026-01-31
**Status:** Production Ready
**Version:** 0.1.0
