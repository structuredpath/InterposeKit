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
