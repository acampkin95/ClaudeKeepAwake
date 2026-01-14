import Foundation
import IOKit.pwr_mgt

final class SleepPreventer {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isPreventingSleep = false
    
    func preventSleep() -> Bool {
        guard !isPreventingSleep else { return true }
        
        let reason = "ClaudeKeepAwake: Keeping system awake for Claude.app" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        
        if result == kIOReturnSuccess {
            isPreventingSleep = true
            return true
        }
        return false
    }
    
    func allowSleep() {
        guard isPreventingSleep else { return }
        
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isPreventingSleep = false
    }
    
    deinit {
        allowSleep()
    }
}
