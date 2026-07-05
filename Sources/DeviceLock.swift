import Foundation

// Attempts a genuine device lock by simulating the hardware power/lock button
// through IOKit HID (the approach TrollStore lock utilities use). Requires the
// unsandboxed/platform-application entitlements the app already has.
enum DeviceLock {
    private typealias CreateClient = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias CreateKeyEvent = @convention(c) (CFAllocator?, UInt64, UInt32, UInt32, UInt8, UInt32) -> Unmanaged<AnyObject>?
    private typealias DispatchEvent = @convention(c) (AnyObject, AnyObject) -> Void

    static func lock() -> Bool {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else { return false }
        defer { dlclose(handle) }
        guard let cCreate = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let cKey = dlsym(handle, "IOHIDEventCreateKeyboardEvent"),
              let cDispatch = dlsym(handle, "IOHIDEventSystemClientDispatchEvent") else { return false }

        let createClient = unsafeBitCast(cCreate, to: CreateClient.self)
        let createKey = unsafeBitCast(cKey, to: CreateKeyEvent.self)
        let dispatchEvent = unsafeBitCast(cDispatch, to: DispatchEvent.self)

        guard let client = createClient(kCFAllocatorDefault)?.takeRetainedValue() else { return false }

        // Consumer usage page 0x0C, Power usage 0x30 = the lock/sleep button.
        let page: UInt32 = 0x0C
        let usage: UInt32 = 0x30
        let ts = mach_absolute_time()

        if let down = createKey(kCFAllocatorDefault, ts, page, usage, 1, 0)?.takeRetainedValue() {
            dispatchEvent(client, down)
        }
        if let up = createKey(kCFAllocatorDefault, mach_absolute_time(), page, usage, 0, 0)?.takeRetainedValue() {
            dispatchEvent(client, up)
        }
        return true
    }
}
