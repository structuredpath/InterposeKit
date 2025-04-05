enum HookExample: CaseIterable {
    case NSWindow_setTitle
    case NSWindow_miniaturize
    case NSApplication_sendEvent
    case NSMenuItem_title
    case NSColor_labelColor
}

extension HookExample {
    var selector: String {
        switch self {
        case .NSWindow_setTitle:
            return "-[NSWindow setTitle:]"
        case .NSWindow_miniaturize:
            return "-[NSWindow miniaturize:]"
        case .NSApplication_sendEvent:
            return "-[NSApplication sendEvent:]"
        case .NSMenuItem_title:
            return "-[NSMenuItem title]"
        case .NSColor_labelColor:
            return "+[NSColor labelColor]"
        }
    }
    
    var description: String {
        switch self {
        case .NSWindow_setTitle:
            return """
            An object hook on the main NSWindow that uppercases the title and wraps it with \
            decorative markers whenever it’s set. This can be tested using the text field below.
            """
        case .NSWindow_miniaturize:
            return """
            An object hook on the main NSWindow that intercepts miniaturization and shows \ 
            an alert instead of minimizing the window. 
            """
        case .NSApplication_sendEvent:
            return """
            A class hook on NSApplication that logs all events passed through sendEvent(_:).
            """
        case .NSMenuItem_title:
            return """
            A class hook on NSMenuItem that wraps all menu item titles with decorative markers, \ 
            visible in the main menu and the text field’s context menu.
            """
        case .NSColor_labelColor:
            return """
            A class hook that overrides the standard label color by hooking the corresponding \
            class method on NSColor. Affects text in this window and menus.
            """
        }
    }
}
