import ApplicationServices
import Foundation

enum AXAttributeNames {
    static let windows = kAXWindowsAttribute as String
    static let focusedWindow = kAXFocusedWindowAttribute as String
    static let focusedUIElement = kAXFocusedUIElementAttribute as String
    static let children = kAXChildrenAttribute as String
    static let parent = kAXParentAttribute as String
    static let role = kAXRoleAttribute as String
    static let subrole = kAXSubroleAttribute as String
    static let title = kAXTitleAttribute as String
    static let value = kAXValueAttribute as String
    static let description = kAXDescriptionAttribute as String
    static let position = kAXPositionAttribute as String
    static let size = kAXSizeAttribute as String
    static let enabled = kAXEnabledAttribute as String
    static let focused = kAXFocusedAttribute as String
    static let selected = kAXSelectedAttribute as String
    static let selectedRows = kAXSelectedRowsAttribute as String
    static let visibleRows = kAXVisibleRowsAttribute as String
    static let rows = kAXRowsAttribute as String
    static let closeButton = kAXCloseButtonAttribute as String
}

enum AXActionNames {
    static let press = kAXPressAction as String
    static let raise = kAXRaiseAction as String
    static let confirm = kAXConfirmAction as String
}

enum AXRoleNames {
    static let window = kAXWindowRole as String
    static let group = kAXGroupRole as String
    static let button = kAXButtonRole as String
    static let textField = kAXTextFieldRole as String
    static let textArea = kAXTextAreaRole as String
    static let scrollArea = kAXScrollAreaRole as String
    static let table = kAXTableRole as String
    static let outline = kAXOutlineRole as String
    static let list = kAXListRole as String
    static let row = kAXRowRole as String
    static let cell = kAXCellRole as String
    static let staticText = kAXStaticTextRole as String
    static let image = kAXImageRole as String
}
