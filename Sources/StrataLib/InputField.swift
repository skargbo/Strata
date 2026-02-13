import AppKit
import SwiftUI

/// A custom text input field that reliably handles Enter to submit.
/// Uses NSTextField directly to avoid SwiftUI's .onSubmit issues.
/// Supports inline ghost-text suggestions accepted with Tab.
struct InputField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Type a message..."
    var suggestion: String? = nil
    var requestFocus: Binding<Bool>? = nil
    var onSubmit: () -> Void
    var onCycleSuggestion: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        field.isBordered = false
        field.isBezeled = false
        field.focusRingType = .none
        field.drawsBackground = false
        field.lineBreakMode = .byTruncatingTail
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.enterPressed(_:))
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        context.coordinator.parent = self

        // Show suggestion as ghost placeholder text
        if let suggestion = suggestion, !suggestion.isEmpty, text.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.4),
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            ]
            field.placeholderAttributedString = NSAttributedString(string: suggestion, attributes: attrs)
        } else {
            field.placeholderAttributedString = nil
            field.placeholderString = placeholder
        }

        if requestFocus?.wrappedValue == true {
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
                requestFocus?.wrappedValue = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: InputField

        init(parent: InputField) {
            self.parent = parent
            super.init()
        }

        @objc func enterPressed(_ sender: NSTextField) {
            let value = sender.stringValue
            parent.text = value
            parent.onSubmit()
            sender.stringValue = ""
            parent.text = ""
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let field = control as? NSTextField {
                    enterPressed(field)
                }
                return true
            }

            // Tab: accept the ghost suggestion
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                if let suggestion = parent.suggestion, !suggestion.isEmpty,
                   let field = control as? NSTextField, field.stringValue.isEmpty {
                    field.stringValue = suggestion
                    parent.text = suggestion
                    return true
                }
                return false
            }

            // Shift+Tab: cycle to next suggestion
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                if parent.suggestion != nil {
                    parent.onCycleSuggestion?()
                    return true
                }
                return false
            }

            return false
        }
    }
}
