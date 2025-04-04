enum HookExample: CaseIterable {
    case NSApplication_sendEvent
    case NSWindow_setTitle
    case NSMenuItem_title
    case NSColor_controlAccentColor
}

extension HookExample {
    var selector: String {
        switch self {
        case .NSApplication_sendEvent:
            return "-[NSApplication sendEvent:]"
        case .NSWindow_setTitle:
            return "-[NSWindow setTitle:]"
        case .NSMenuItem_title:
            return "-[NSMenuItem title]"
        case .NSColor_controlAccentColor:
            return "+[NSColor controlAccentColor]"
        }
    }
    
    var description: String {
        switch self {
        case .NSApplication_sendEvent:
            return """
            An object hook on the shared NSApplication instance that logs all events passed \ 
            through sendEvent(_:).
            """
        case .NSWindow_setTitle:
            return """
            An object hook on the main NSWindow that uppercases the title and wraps it with \
            decorative markers whenever it’s set. This can be tested using the text field below.
            """
        case .NSMenuItem_title:
            return """
            A class hook on NSMenuItem that wraps all menu item titles with decorative markers, \ 
            visible in the main menu and the text field’s context menu.
            """
        case .NSColor_controlAccentColor:
            return """
            A class hook that overrides the system accent color by hooking the corresponding \
            class method on NSColor. (Not implemented.)
            """
        }
    }
}
