import Foundation

enum DeviceLock {
    // Attempts a genuine device lock via a private GraphicsServices symbol.
    // Returns true only if the symbol was found and invoked. If it isn't present
    // on this iOS build, returns false so the caller can fall back to screen-off.
    static func lock() -> Bool {
        let path = "/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices"
        guard let handle = dlopen(path, RTLD_LAZY) else { return false }
        defer { dlclose(handle) }
        guard let sym = dlsym(handle, "GSEventLockDevice") else { return false }
        typealias LockFn = @convention(c) () -> Void
        let fn = unsafeBitCast(sym, to: LockFn.self)
        fn()
        return true
    }
}
