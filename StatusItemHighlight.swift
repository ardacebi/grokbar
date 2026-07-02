import AppKit

enum StatusItemHighlight {
    static func setHighlighted(_ highlighted: Bool, on button: NSStatusBarButton?) {
        guard let button else { return }
        button.highlight(highlighted)
        if !highlighted {
            button.state = .off
        }
    }

    static func clear(on button: NSStatusBarButton?) {
        setHighlighted(false, on: button)
        DispatchQueue.main.async {
            setHighlighted(false, on: button)
        }
    }
}