import Foundation

/// Generates the wrong-layout demo string for the welcome sandbox (spec:
/// welcome-onboarding, step 2). The result is what the user's selected text
/// looks like when typed with the next enabled layout active — the exact
/// inverse of the app's fix path, so selecting the demo text and pressing the
/// hotkey genuinely fixes it in place.
public enum SandboxDemoText {

    /// - Returns: `text` (expressed in `next`'s character set — e.g. Latin
    ///   "shift happens" for the ABC layout) rendered through the `active`
    ///   layout's keymap: what the user would have gotten typing those keys
    ///   with the wrong layout on. The Orchestrator's fix path
    ///   (`translate(selected, active → next)`) then maps it back exactly.
    ///   Returns `nil` when a keymap is missing, when `next` cannot produce
    ///   `text`'s characters, or when the translation is a no-op (unusable
    ///   demo, e.g. identical layouts).
    public static func generate(text: String, active: Keymap?, next: Keymap?) -> String? {
        guard let active, let next, isProducible(text, by: next) else { return nil }
        let result = KeymapTranslator.translate(text, source: next, target: active)
        return result == text ? nil : result
    }

    /// Every character of `text` must be a character the `keymap` can produce —
    /// otherwise `KeymapTranslator` would pass unproducible chars through and
    /// the "demo" would be mixed garbage.
    private static func isProducible(_ text: String, by keymap: Keymap) -> Bool {
        let produced = Set(keymap.base.values).union(keymap.shift.values)
        return text.allSatisfy { produced.contains($0) }
    }
}
