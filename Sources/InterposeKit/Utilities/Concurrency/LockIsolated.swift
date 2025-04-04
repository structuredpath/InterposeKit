// A modified version from Point-Free’s Concurrency Extras package:
// https://github.com/pointfreeco/swift-concurrency-extras
//
// Copyright (c) 2023 Point-Free
// Licensed under the MIT license.

import Foundation

internal final class LockIsolated<Value>: @unchecked Sendable {
    private var _value: Value
    private let lock = NSRecursiveLock()
    
    internal init(_ value: @autoclosure @Sendable () throws -> Value) rethrows {
        self._value = try value()
    }
    
    internal var value: Value {
        self.lock.sync {
            self._value
        }
    }
    
    internal func withValue<T: Sendable>(
        _ operation: @Sendable (inout Value) throws -> T
    ) rethrows -> T {
        try self.lock.sync {
            var value = self._value
            defer { self._value = value }
            return try operation(&value)
        }
    }
}

extension NSRecursiveLock {
    @discardableResult
    fileprivate func sync<R>(work: () throws -> R) rethrows -> R {
        self.lock()
        defer { self.unlock() }
        return try work()
    }
}
