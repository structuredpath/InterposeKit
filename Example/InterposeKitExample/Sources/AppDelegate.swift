import AppKit
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "InterposeKit Example"
        window.contentViewController = self.hostingController
        
        return window
    }()
    
    private lazy var hostingController: NSViewController = {
        return NSHostingController(rootView: ContentView())
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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

fileprivate struct ContentView: View {
    fileprivate var body: some View {
        Text("Hello from InterposeKit!")
            .font(.title)
            .fixedSize()
            .padding(200)
    }
}
