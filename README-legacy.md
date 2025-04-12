## Usage

Want to hook just a single instance? No problem!

```swift
let hook = try testObj.hook(
    #selector(TestClass.sayHi),
    methodSignature: (@convention(c) (AnyObject, Selector) -> String).self,
    hookSignature: (@convention(block) (AnyObject) -> String).self) { store in { `self` in
        return store.original(`self`, store.selector) + "just this instance"
        }
}
```

## Object Hooking

InterposeKit can hook classes and object. Class hooking is similar to swizzling, but object-based hooking offers a variety of new ways to set hooks. This is achieved via creating a dynamic subclass at runtime. 

Caveat: Hooking will fail with an error if the object uses KVO. The KVO machinery is fragile and it's to easy to cause a crash. Using KVO after a hook was created is supported and will not cause issues.

## FAQ

### Why didn't you call it Interpose? "Kit" feels so old-school.
Naming it Interpose was the plan, but then [SR-898](https://bugs.swift.org/browse/SR-898) came. While having a class with the same name as the module works [in most cases](https://forums.swift.org/t/frameworkname-is-not-a-member-type-of-frameworkname-errors-inside-swiftinterface/28962), [this breaks](https://twitter.com/BalestraPatrick/status/1260928023357878273) when you enable build-for-distribution. There's some [discussion](https://forums.swift.org/t/pitch-fully-qualified-name-syntax/28482/81) to get that fixed, but this will be more towards end of 2020, if even.

### I want to hook into Swift! You made another ObjC swizzle thingy, why?
UIKit and AppKit won't go away, and the bugs won't go away either. I see this as a rarely-needed instrument to fix system-level issues. There are ways to do some of that in Swift, but that's a separate (and much more difficult!) project. (See [Dynamic function replacement #20333](https://github.com/apple/swift/pull/20333) aka `@_dynamicReplacement` for details.)

### Can I ship this?
Yes, absolutely. The goal for this one project is a simple library that doesn't try to be too smart. I did this in [Aspects](https://github.com/steipete/Aspects) and while I loved this to no end, it's problematic and can cause side-effects with other code that tries to be clever. InterposeKit is boring, so you don't have to worry about conditions like "We added New Relic to our app and now [your thing crashes](https://github.com/steipete/Aspects/issues/21)".

## Improvement Ideas

- Write proposal to allow to [convert the calling convention of existing types](https://twitter.com/steipete/status/1266799174563041282?s=21).
- Use the C block struct to perform type checking between Method type and C type (I do that in  [Aspects library](https://github.com/steipete/Aspects)), it's still a runtime crash but could be at hook time, not when we call it.
- Add a way to get all current hooks from an object/class.
- Switch to Trampolines to manage cases where other code overrides super, so we end up with a super call that's [not on top of the class hierarchy](https://github.com/steipete/InterposeKit/pull/15#discussion_r439871752).
