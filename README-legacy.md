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

## Improvement Ideas

- Write proposal to allow to [convert the calling convention of existing types](https://twitter.com/steipete/status/1266799174563041282?s=21).
- Use the C block struct to perform type checking between Method type and C type (I do that in  [Aspects library](https://github.com/steipete/Aspects)), it's still a runtime crash but could be at hook time, not when we call it.
- Add a way to get all current hooks from an object/class.
- Switch to Trampolines to manage cases where other code overrides super, so we end up with a super call that's [not on top of the class hierarchy](https://github.com/steipete/InterposeKit/pull/15#discussion_r439871752).
