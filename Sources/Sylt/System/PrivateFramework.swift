import Foundation

struct PrivateFramework {
    private let handle: UnsafeMutableRawPointer?

    init(_ path: String) {
        handle = dlopen(path, RTLD_NOW)
    }

    init(private name: String) {
        self.init("/System/Library/PrivateFrameworks/\(name).framework/\(name)")
    }

    func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }
}
