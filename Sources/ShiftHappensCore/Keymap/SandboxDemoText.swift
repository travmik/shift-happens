import Foundation

/// Generates the wrong-layout demo string for the welcome sandbox (spec:
/// welcome-onboarding, step 2). The result is what the user's selected text
/// looks like when typed with the next enabled layout active — the exact
/// inverse of the app's fix path, so selecting the demo text and pressing the
/// hotkey genuinely fixes it in place.
public enum SandboxDemoText {

    /// - Returns: `text` remapped from the active layout's keymap into the
    ///   next enabled layout's keymap, or `nil` when a keymap is missing or
    ///   the translation is a no-op (unusable demo, e.g. identical layouts).
    public static func generate(text: String, active: Keymap?, next: Keymap?) -> String? {
        guard let active, let next else { return nil }
        let result = KeymapTranslator.translate(text, source: active, target: next)
        return result == text ? nil : result
    }
}
