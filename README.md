# InterposeKit

[![CI](https://github.com/structuredpath/InterposeKit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/structuredpath/InterposeKit/actions/workflows/ci.yml) ![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg) ![Xcode 15+](https://img.shields.io/badge/Xcode-15%2B-blue.svg)

**InterposeKit** is a modern library for hooking Objective-C methods in Swift, also known as method swizzling. It supports both class-based and object-based hooks, and it provides a clean, block-based, Swift-friendly API.

This is a continuation and modernization of [Peter Steinberger’s original implementation](https://github.com/steipete/InterposeKit). <!-- For the background on why and how this revamp came about, see [my blog post](#). --> If you’re migrating, check out [what’s changed](#what-has-changed).

## Key Features

- Swift-friendly, modern, and minimal API.
- Block-based hooks using direct `Method` implementation replacement under the hood rather than less-safe [selector-based swizzling](https://pspdfkit.com/blog/2019/swizzling-in-swift/). 
- Ability to target both classes and individual objects.  
- Support for both instance and class methods.
- Object hooks are safely isolated using runtime subclassing, similar to the KVO mechanism.
- Hooks get access to the original method implementation via a proxy.
- Hooks can be applied immediately or prepared and applied later, and safely reverted at any time[^1].
- Typed signatures must be explicitly provided for both the original method and the hook block. This adds some boilerplate but ensures a clean API and better performance compared to using `NSInvocation`[^2].
- Written almost entirely in Swift on top of the Objective-C runtime[^3].

## Requirements

- Swift 5.9 or later
- Xcode 15 or later
- Apple platforms only (macOS, iOS, tvOS, watchOS)
- `arm64` or `x86_64` architectures

## Installation

You can add InterposeKit to your project using the Swift Package Manager.

In Xcode, open your project settings, select the *Package Dependencies* tab, click the *+* button, and enter the URL `https://github.com/structuredpath/InterposeKit`. Then select the latest version and add the package to your desired target.

If you’re adding InterposeKit using a `Package.swift` manifest, include it in your `dependencies` like this:

```
dependencies: [
    .package(url: "https://github.com/structuredpath/InterposeKit", from: "0.5.0")
]
```

Then add the product to any target that needs it:

```
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "InterposeKit", package: "InterposeKit")
    ]
)
```

## Usage

### Class Hook on Instance Method 

```swift
class MyClass: NSObject {
    @objc dynamic func getValue() -> Int {
        return 42
    }
}

let object = MyClass()
print(object.getValue()) // => 42

let hook = try Interpose.applyHook(
    on: MyClass.self,
    for: #selector(MyClass.getValue),
    methodSignature: (@convention(c) (MyClass, Selector) -> Int).self,
    hookSignature: (@convention(block) (MyClass) -> Int).self
) { hook in
    return { `self` in
        // Retrieve the original result and add 1 to it. This can be skipped.
        return hook.original(`self`, hook.selector) + 1
    }
}

print(object.getValue()) // => 43

try hook.revert()
print(object.getValue()) // => 42
```

### Class Hook on Class Method

```swift
class MyClass: NSObject {
    @objc dynamic class func getStaticValue() -> Int {
        return 42
    }
}

print(MyClass.getStaticValue()) // => 42

let hook = try Interpose.applyHook(
    on: MyClass.self,
    for: #selector(MyClass.getStaticValue),
    methodKind: .class,
    methodSignature: (@convention(c) (MyClass.Type, Selector) -> Int).self,
    hookSignature: (@convention(block) (MyClass.Type) -> Int).self
) { hook in
    return { `class` in
        // Retrieve the original result and add 1 to it. This can be skipped.
        return hook.original(`class`, hook.selector) + 1
    }
}

print(MyClass.getStaticValue()) // => 43

try hook.revert()
print(MyClass.getStaticValue()) // => 42
```

### Object Hook

```swift
class MyClass: NSObject {
    @objc dynamic func getValue() -> Int {
        return 42
    }
}

let object1 = MyClass()
let object2 = MyClass()

print(object1.getValue()) // => 42
print(object2.getValue()) // => 42

let hook = try Interpose.applyHook(
    on: object1,
    for: #selector(MyClass.getValue),
    methodSignature: (@convention(c) (MyClass, Selector) -> Int).self,
    hookSignature: (@convention(block) (MyClass) -> Int).self
) { hook in
    return { `self` in
        // Retrieve the original result and add 1 to it. This can be skipped.
        return hook.original(`self`, hook.selector) + 1
    }
}

print(object1.getValue()) // => 43
print(object2.getValue()) // => 42

try hook.revert()

print(object1.getValue()) // => 42
print(object2.getValue()) // => 42
```

> [!IMPORTANT]  
> If the object is already being observed via KVO when you apply or revert the hook, the operation will fail safely by throwing `InterposeError.kvoDetected(object:)`. Using KVO after the hook is installed is fully supported.

### More Examples

You can check out the extensive test suite to see more advanced examples. The repository also comes with and example Xcode project, which showcases more real-life examples of tweaking AppKit classes.

<!-- Screenshot of example app -->

<h2 id="what-has-changed">What’s Changed</h2> 

Compared to the [original implementation](https://github.com/steipete/InterposeKit), this fork introduces several API and internal changes. Here is a summary of key differences with migration hints.

### Environment

- Switched the library to Swift Package Manager only. Carthage and CocoaPods support was removed.
- Raised minimum Swift version to 5.9.
- Limited to Apple platforms with `arm64` and `x86_64` architectures. Support for Linux was removed.

### API Changes

- Class hooks now support class methods.
- Removed the builder-based API `Interpose(…) { … }` for applying hooks in batches. Each hook must now be individually prepared, applied, and reverted.
- Signature types must now be specified via parameters, improving clarity and streamlining the API.
- Renamed `hook(…)` methods to `applyHook(…)`.
- Removed fluent-style `Hook` API, meaning that methods no longer return `self`.
- Introduced `HookProxy`, which is passed into the hook builder. It still provides access to the original method implementation and selector, but hides other irrelevant APIs like `revert()`.
- Hook types now use composition instead of inheritance. The public `Hook` class delegates to internal strategies conforming to `HookStrategy`.
- Object hooks now use a global counter instead of UUIDs for dynamic subclass names.
- Dynamic subclasses created at runtime are now cleaned up when the last hook is reverted on an object.
- Class hooks must now target the exact class that actually implements the method to ensure the revert functionality works correctly.
- Added initial Swift 6 support with basic concurrency checks. Should be thread-safe but most usage is still expected to be single-threaded. 
- Removed support for [delayed hooking](https://github.com/steipete/InterposeKit?tab=readme-ov-file#delayed-hooking) via `Interpose.whenAvailable(…)` to keep the library laser-focused.
- …and heavily refactored the Swift part of the codebase: cleaner use of Objective-C runtime APIs, a revamped `InterposeError` enum, and new supporting types like `HookScope` or `HookState`.

### Fixes

- Fixed a crash where `IKTAddSuperImplementationToClass` was stripped in release builds per [steipete/InterposeKit#29](https://github.com/steipete/InterposeKit/issues/29) by using the fix from [steipete/InterposeKit#30](https://github.com/steipete/InterposeKit/issues/30) submitted by [@Thomvis](https://github.com/Thomvis), which replaces a call via dynamic library with a direct Swift call to `IKTSuperBuilder.addSuperInstanceMethod(to:selector:)`.
- Fixed floating-point register handling on arm64 using the patch from [steipete/InterposeKit#37](https://github.com/steipete/InterposeKit/issues/37) submitted by [@ishutinvv](https://github.com/ishutinvv), which resolves an issue affecting swizzled methods with `CGFloat` parameters or structs like `CGPoint` and `CGRect` due to floating-point registers not being restored in the correct order after the trampoline call.

## Q&A

### Why is it called InterposeKit?

Peter originally wanted to go with _Interpose_, but [Swift had (and still has) a bug](https://github.com/swiftlang/swift/issues/43510) where using the same name for a module and a type can break things in certain scenarios.

### Why another Objective-C swizzling library?

UIKit, AppKit, and other system frameworks written in Objective-C won’t go away and sometimes you still need to swizzle to fix bugs or tweak internal behavior. InterposeKit is meant as a rarely-needed tool for these cases, providing a simple, Swift-friendly API.

### What the fork?

This version of InterposeKit started as a fork of [Peter Steinberger’s original library](https://github.com/steipete/InterposeKit) but has since evolved into a significantly reworked and modernized version. The core ideas and underlying runtime techniques remain, but large parts of the Swift codebase were restructured and rewritten. <!-- To learn more about my motivation, see [my blog post](#). -->

### Can I hook Swift methods? And what about pure C functions?

No. Peter had plans to experiment with [Swift method hooking](https://github.com/rodionovd/SWRoute), [Swift dynamic function replacement](https://github.com/swiftlang/swift/pull/20333), and hooking C functions via [`dyld_dynamic_interpose`](https://twitter.com/steipete/status/1258482647933870080), but none made it into the library. And honestly, it doesn’t really fit the scope of this library anyway. 

### Can I ship this?

Modifying the internal behavior of system frameworks always carries risks. You should know what you’re doing, use defensive programming techniques, and assume that future OS updates might break your hooks.

That said, InterposeKit is designed to be safe for production use. It includes guardrails that verify method state before applying or reverting hooks, helping catch unexpected conditions early. The focus is on simplicity and predictability, avoiding clever tricks that could introduce hidden side effects.

## Improvement Ideas

- Support for hooking KVO-enabled objects ([#19](https://github.com/structuredpath/InterposeKit/issues/19))
- Correct super lookup when injecting a trampoline into classes with overridden methods ([#21](https://github.com/structuredpath/InterposeKit/issues/21))
- Signature type checking at hook construction ([#20](https://github.com/structuredpath/InterposeKit/issues/20))
- A way for retrieving all hooks on an object/class
- Support for reverting multiple hooks on a class in an arbitrary order ([#12](https://github.com/structuredpath/InterposeKit/issues/12))

## References

- [Peter’s original implementation](https://github.com/steipete/InterposeKit)
- [Peter’s introductory blog post](https://steipete.me/posts/interposekit/)
- [Peter’s blog post on swizzling in Swift](https://www.nutrient.io/blog/swizzling-in-swift/)
- [Peter’s blog post on calling super at runtime](https://steipete.me/posts/calling-super-at-runtime/)
- [Aspects - Objective-C predecessor to InterposeKit](https://github.com/steipete/Aspects)
- [NSHipster on method swizzling](https://nshipster.com/method-swizzling/)
- [Stack Overflow: How do I remove instance methods at runtime in Objective-C 2.0?](https://stackoverflow.com/questions/1315169/how-do-i-remove-instance-methods-at-runtime-in-objective-c-2-0)

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.

[^1]: Both applying and reverting a hook include safety checks. InterposeKit detects if the method was modified externally—such as by KVO or other swizzling—and prevents the operation if it would lead to inconsistent behavior.
[^2]: There’s currently no runtime type checking. If the specified types don’t match, it will cause a runtime crash. 
[^3]: The most advanced part of this library is `ITKSuperBuilder`, a component for constructing method implementations that simply call `super`, which is [surprisingly hard to do](https://steipete.me/posts/calling-super-at-runtime/). It’s written in Objective-C and assembly, lives in its own SPM target, and is invoked from Swift. All credit goes to Peter, who originally came up with this masterpiece!
