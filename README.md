# InterposeKit

[![CI](https://github.com/structuredpath/InterposeKit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/structuredpath/InterposeKit/actions/workflows/ci.yml) ![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg) ![Xcode 15+](https://img.shields.io/badge/Xcode-15%2B-blue.svg)

**InterposeKit** is a modern library for hooking Objective-C methods in Swift, also known as method swizzling. It supports both class-based and object-based hooks and it provides a clean, block-based, Swift-friendly API.

This is a continuation and modernization of [Peter Steinberger’s original implementation](https://github.com/steipete/InterposeKit). For the background on why and how this revamp came about, see [my blog post](#). If you’re migrating, check out [what’s changed](#).

## Key Features

- Swift-friendly, modern, and minimal API.
- Block-based hooks targeting both classes and individual objects.
- Support for both instance and class methods.
- Hooks get access to the original implementation via a proxy.
- Object hooks are safely isolated using runtime subclassing, similar to the KVO mechanism.
- Hooks can be applied immediately or prepared and applied later, and safely reverted at any time[^1].
- Direct `Method` implementation replacement rather than less-safe [selector-based swizzling](https://pspdfkit.com/blog/2019/swizzling-in-swift/).
- Typed signatures must be provided for both the original method and the hook block, enabling an ergonomic API.
- There’s no runtime type checking, and the signature has to be written twice—a trade-off to avoid `NSInvocation`.
- Written almost entirely in Swift on top of the Objective-C runtime[^2].

## Requirements

- Swift 5.9 or later
- Xcode 15 or later
- Apple platforms only (macOS, iOS, tvOS, watchOS)
- arm64 or x86_64 architectures

## Installation

You can add InterposeKit to your project using the Swift Package Manager.

In Xcode, open your project settings, select the *Package Dependencies* tab, click the *+* button, and enter the URL `https://github.com/structuredpath/InterposeKit`. Then select the latest version and add the package to your desired target.

If you’re adding InterposeKit using a `Package.swift` manifest, include it in your `dependencies` like this:

```swift
dependencies: [
  .package(url: "https://github.com/structuredpath/InterposeKit", from: "1.0.0")
]
```

Then add the product to any target that needs it:

```swift
.target(
  name: "YourTarget",
  dependencies: [
    .product(name: "InterposeKit", package: "InterposeKit")
  ]
)
```

## Usage

### Class Hook: Instance Method 

…

### Class Hook: Class Method

…

### Object Hook

…  

## What’s Changed

Compared to the [original implementation](https://github.com/steipete/InterposeKit), this fork introduces several API and internal changes. Here is a summary of key differences with migration hints.

### Environment

- Switched the library to Swift Package Manager only. Carthage and CocoaPods support was removed.
- Raised minimum Swift version to 5.9.
- Limited to Apple platforms with arm64 and x86_64 architectures. Support for Linux was removed.

### API Changes

- Class hooks now support class methods.
- Removed the builder-based API `Interpose(…) { … }` for applying hooks in batches. Each hook must now be individually prepared, applied, and reverted.
- Signature types must now be specified via parameters, improving clarity and streamlining the API.
- Renamed `hook(…)` methods to `applyHook(…)`.
- Removed fluent-style `Hook` API, meaning that methods no longer return `self`.
- Introduced `HookProxy`, which is passed into the hook builder. It still provides access to the original method implementation and selector, but hides irrelevant APIs like `revert()`.
- Hook types now use composition instead of inheritance. The public `Hook` class delegates to internal strategies conforming to `HookStrategy`.
- Object hooks now use a global counter instead of UUIDs for dynamic subclass names.
- Dynamic subclasses created at runtime are now cleaned up when the last hook is reverted on an object.
- Class hooks must now target the exact class that actually implements the method to ensure the revert functionality works correctly.
- Added initial Swift 6 support with basic concurrency checks. Should be thread-safe, but most usage is still expected to be single-threaded. 
- Removed support for [delayed hooking](https://steipete.com/posts/mac-catalyst-crash-hunt/) (`whenAvailable(…)`) to keep the library laser-focused.
- …and heavily refactored the Swift part of the codebase: cleaner use of Objective-C runtime APIs, a revamped `InterposeError` enum, and new supporting types like `HookScope` or `HookState`.

### Fixes

- Fixed a crash where `IKTAddSuperImplementationToClass` was stripped in release builds per [steipete/InterposeKit#29](https://github.com/steipete/InterposeKit/issues/29) by using the fix from [steipete/InterposeKit#30](https://github.com/steipete/InterposeKit/issues/30) submitted by @Thomvis, which replaces a call via dynamic library with a direct Swift call to `IKTSuperBuilder.addSuperInstanceMethod(to:selector:)`.
- Fixed floating-point register handling on arm64 using the patch from [steipete/InterposeKit#37](https://github.com/steipete/InterposeKit/issues/37) submitted by @ishutinvv, which resolves an issue affecting swizzled methods with `CGFloat` parameters or structs like `CGPoint` and `CGRect` due to floating-point registers not being restored in the correct order after the trampoline call.

## References

- [Peter’s original implementation](https://github.com/steipete/InterposeKit)
- [Peter’s introductory blog post](https://steipete.me/posts/interposekit/)
- [Peter’s blog post on swizzling in Swift](https://www.nutrient.io/blog/swizzling-in-swift/)
- [Peter’s blog post on calling super at runtime](https://steipete.me/posts/calling-super-at-runtime/)
- [Aspects - Objective-C predecessor to InterposeKit](https://github.com/steipete/Aspects)
- [NSHipster on method swizzling](https://nshipster.com/method-swizzling/)
- [Stack Overflow: How do I remove instance methods at runtime in Objective-C 2.0?](https://stackoverflow.com/questions/1315169/how-do-i-remove-instance-methods-at-runtime-in-objective-c-2-0)

## License

InterposeKit is available under the [MIT license](LICENSE).

[^1]: Both applying and reverting a hook include safety checks. InterposeKit detects if the method was modified externally—such as by KVO or other swizzling—and prevents the operation if it would lead to inconsistent behavior.
[^2]: The most advanced part of this library is `ITKSuperBuilder`, a component for constructing method implementations that simply call `super`, which is [surprisingly hard to do](https://steipete.me/posts/calling-super-at-runtime/). It’s written in Objective-C and assembly, lives in its own SPM target, and is invoked from Swift. All credit goes to Peter who originally came up with this masterpiece!
