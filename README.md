# InterposeKit

[![CI](https://github.com/structuredpath/InterposeKit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/structuredpath/InterposeKit/actions/workflows/ci.yml) ![Xcode 15+](https://img.shields.io/badge/Xcode-15%2B-blue.svg) ![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)

**InterposeKit** is a modern library for hooking Objective-C methods in Swift, also known as method swizzling. It supports both class-based and object-based hooks and it provides a clean, block-based, Swift-friendly API.

This is a continuation and modernization of [Peter Steinberger’s original implementation](https://github.com/steipete/InterposeKit). For the background on why and how this revamp came about, see [my blog post](#). If you’re migrating, check out [what’s changed](#).

## Key Features

- Swift-friendly, minimal, thread-safe API.
- Block-based hooks targeting both classes and individual objects.
- Support for both instance and class methods.
- Hooks get access to the original implementation via a proxy.
- Object hooks are safely isolated using runtime subclassing, similar to the KVO mechanism.
- Hooks can be applied immediately or prepared and applied later, and safely reverted at any time[^1].
- Direct `Method` implementation replacement rather than less-safe [selector-based swizzling](https://pspdfkit.com/blog/2019/swizzling-in-swift/).
- Typed signatures must be provided for both the original method and the hook block, enabling an ergonomic API.
- There’s no runtime type checking, and the signature has to be written twice—a trade-off to avoid `NSInvocation`.
- Written almost entirely in Swift on top of the Objective-C runtime[^2].

## Getting Started

- Installation Swift Package Manager
- Swift 5.9+, Xcode 15+
- arm64 and x86_64 architectures
- Examples: instance method on class, class method on class, object  

## Changes from [Original Implementation](https://github.com/steipete/InterposeKit)

- ...

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
