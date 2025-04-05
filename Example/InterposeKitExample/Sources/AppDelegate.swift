import AppKit
import InterposeKit
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // ============================================================================ //
    // MARK: Window & Content View
    // ============================================================================ //
    
    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        let hostingController = NSHostingController(rootView: self.contentView)
        window.contentViewController = hostingController
        return window
    }()
    
    private lazy var contentView: ContentView = {
        ContentView(
            onHookToggled: { [weak self] example, isEnabled in
                guard let self else { return }
                
                let hook = self.hook(for: example)
                
                do {
                    if isEnabled {
                        try hook.apply()
                    } else {
                        try hook.revert()
                    }
                } catch {
                    fatalError("\(error)")
                }
            },
            onWindowTitleChanged: { [weak self] title in
                self?.window.title = title
            }
        )
    }()
    
    // ============================================================================ //
    // MARK: Hooks
    // ============================================================================ //
    
    private func hook(
        for example: HookExample
    ) -> Hook {
        if let hook = self._hooks[example] { return hook }
        
        let hook = self._makeHook(for: example)
        self._hooks[example] = hook
        return hook
    }
    
    private func _makeHook(
        for example: HookExample
    ) -> Hook {
        do {
            switch example {
            case .NSApplication_sendEvent:
                return try Interpose.prepareHook(
                    on: NSApplication.shared,
                    for: #selector(NSApplication.sendEvent(_:)),
                    methodSignature: (@convention(c) (NSApplication, Selector, NSEvent) -> Void).self,
                    hookSignature: (@convention(block) (NSApplication, NSEvent) -> Void).self
                ) { hook in
                    return { `self`, event in
                        print("NSApplication.sendEvent(_:) \(event)")
                        hook.original(self, hook.selector, event)
                    }
                }
            case .NSWindow_setTitle:
                return try Interpose.prepareHook(
                    on: self.window,
                    for: #selector(setter: NSWindow.title),
                    methodSignature: (@convention(c) (NSWindow, Selector, String) -> Void).self,
                    hookSignature: (@convention(block) (NSWindow, String) -> Void).self
                ) { hook in
                    return { `self`, title in
                        hook.original(self, hook.selector, "## \(title.uppercased()) ##")
                    }
                }
            case .NSMenuItem_title:
                return try Interpose.prepareHook(
                    on: NSMenuItem.self,
                    for: #selector(getter: NSMenuItem.title),
                    methodSignature: (@convention(c) (NSMenuItem, Selector) -> String).self,
                    hookSignature: (@convention(block) (NSMenuItem) -> String).self
                ) { hook in
                    return { `self` in
                        let title = hook.original(`self`, hook.selector)
                        return "## \(title) ##"
                    }
                }
            case .NSColor_labelColor:
                return try Interpose.prepareHook(
                    on: NSColor.self,
                    for: #selector(getter: NSColor.labelColor),
                    methodKind: .class,
                    methodSignature: (@convention(c) (NSColor.Type, Selector) -> NSColor).self,
                    hookSignature: (@convention(block) (NSColor.Type) -> NSColor).self
                ) { hook in
                    return { `self` in
                        return self.systemPink
                    }
                }
            }
        } catch {
            fatalError("\(error)")
        }
    }
    
    private var _hooks = [HookExample: Hook]()
    
    // ============================================================================ //
    // MARK: NSApplicationDelegate
    // ============================================================================ //
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        Interpose.isLoggingEnabled = true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        self.window.contentView?.layoutSubtreeIfNeeded()
        
        Task { @MainActor in
            self.window.center()
            self.window.makeKeyAndOrderFront(nil)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        return true
    }
    
}
