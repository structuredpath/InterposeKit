#if !(defined(__APPLE__) && (defined(__arm64__) || defined(__x86_64__)))
#error "[InterposeKit] Supported only on Apple platforms with arm64 or x86_64 architecture."
#endif

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
Adds an empty super implementation instance method to originalClass.
If a method already exists, this will return NO and a descriptive error message.

Example: You have an empty UIViewController subclass and call this with viewDidLoad as selector.
The result will be code that looks similar to this:

override func viewDidLoad() {
    super.viewDidLoad()
}

What the compiler creates in following code:

- (void)viewDidLoad {
    struct objc_super _super = {
        .receiver = self,
        .super_class = object_getClass(obj);
    };
    objc_msgSendSuper2(&_super, _cmd);
}

There are a few important details:

1) We use objc_msgSendSuper2, not objc_msgSendSuper.
  The difference is minor, but important.
  objc_msgSendSuper starts looking at the current class, which would cause an endless loop
  objc_msgSendSuper2 looks for the superclass.

2) This uses a completely dynamic lookup.
  While slightly slower, this is resilient even if you change superclasses later on.

3) The resolution method calls out to C, so it could be customized to jump over specific implementations.
  (Such API is not currently exposed)

4) This uses inline assembly to forward the parameters to objc_msgSendSuper2 and objc_msgSendSuper2_stret.
  This is currently implemented architectures are x86_64 and arm64.
  armv7 was dropped in OS 11 and i386 with macOS Catalina.

@see https://steipete.com/posts/calling-super-at-runtime/
*/
@interface ITKSuperBuilder: NSObject

/// Adds an empty super implementation instance method to originalClass.
/// If a method already exists, this will return NO and a descriptive error message.
+ (BOOL)addSuperInstanceMethodToClass:(Class)originalClass
                             selector:(SEL)selector
                                error:(NSError **)error;

/// Check if the instance method in `originalClass` is a super trampoline.
+ (BOOL)isSuperTrampolineForClass:(Class)originalClass
                         selector:(SEL)selector;

@end

NSString *const ITKSuperBuilderErrorDomain;

typedef NS_ERROR_ENUM(ITKSuperBuilderErrorDomain, ITKSuperBuilderErrorCode) {
    SuperBuilderErrorCodeNoSuperClass,
    SuperBuilderErrorCodeNoDynamicallyDispatchedMethodAvailable,
    SuperBuilderErrorCodeFailedToAddMethod
};

NS_ASSUME_NONNULL_END
