import XCTest
@testable import ShiftHappensCore

final class SandboxDemoTextTests: XCTestCase {

    // Fake layouts over shared keycodes: 's'=1, 'h'=2, 'i'=3, 'f'=4, 't'=5,
    // ' '=6, 'a'=7, 'p'=8, 'e'=9, 'n'=10.
    private func latinKeymap() -> Keymap {
        let base: [UInt64: Character] = [1: "s", 2: "h", 3: "i", 4: "f", 5: "t", 6: " ", 7: "a", 8: "p", 9: "e", 10: "n"]
        return Keymap(base: base, shift: [:])
    }

    private func cyrillicKeymap() -> Keymap {
        let base: [UInt64: Character] = [1: "ы", 2: "р", 3: "ш", 4: "а", 5: "е", 6: " ", 7: "ф", 8: "з", 9: "у", 10: "т"]
        return Keymap(base: base, shift: [:])
    }

    func test_generate_rendersIntendedTextThroughActiveLayout() {
        // Intended "shift happens" (ABC charset), active layout is Cyrillic:
        // the sandbox shows what the user would have gotten typing those keys.
        let result = SandboxDemoText.generate(text: "shift happens",
                                              active: cyrillicKeymap(),
                                              next: latinKeymap())
        XCTAssertEqual(result, "ыршае рфззуты")
    }

    func test_generate_returnsNilWhenActiveKeymapMissing() {
        XCTAssertNil(SandboxDemoText.generate(text: "shift happens", active: nil, next: latinKeymap()))
    }

    func test_generate_returnsNilWhenNextKeymapMissing() {
        XCTAssertNil(SandboxDemoText.generate(text: "shift happens", active: cyrillicKeymap(), next: nil))
    }

    func test_generate_returnsNilWhenIntendedNotProducibleByNext() {
        // Latin "shift happens" cannot come from the Cyrillic layout → no demo.
        XCTAssertNil(SandboxDemoText.generate(text: "shift happens",
                                              active: latinKeymap(),
                                              next: cyrillicKeymap()))
    }

    func test_generate_returnsNilWhenOnlyPartOfTextProducibleByNext() {
        // Mixed text: 'ы' is producible by the Cyrillic layout, 's' is not —
        // a partial passthrough would produce garbage, so refuse.
        XCTAssertNil(SandboxDemoText.generate(text: "sы",
                                              active: latinKeymap(),
                                              next: cyrillicKeymap()))
    }

    func test_generate_returnsNilWhenTranslationIsNoOp() {
        // Same layout twice: every char maps to itself → unusable demo.
        XCTAssertNil(SandboxDemoText.generate(text: "shift happens",
                                              active: latinKeymap(),
                                              next: latinKeymap()))
    }

    func test_generate_sandboxFixesBackUnderOrchestratorDirection() {
        // End-to-end invariant: hotkey = translate(selected, active → next).
        // The sandbox text must map back to the intended string under that path.
        let sandbox = SandboxDemoText.generate(text: "shift happens",
                                               active: cyrillicKeymap(),
                                               next: latinKeymap())!
        let fixed = KeymapTranslator.translate(sandbox,
                                               source: cyrillicKeymap(),
                                               target: latinKeymap())
        XCTAssertEqual(fixed, "shift happens")
    }
}

final class SandboxDemoCanProduceTests: XCTestCase {
    func test_canProduce_latinLayoutProducesLatinText() {
        let latin = Keymap(base: [1: "s", 2: "h"], shift: [:])
        XCTAssertTrue(SandboxDemoText.canProduce("sh", layout: latin))
    }

    func test_canProduce_cyrillicLayoutRejectsLatinText() {
        let cyr = Keymap(base: [1: "ы", 2: "р"], shift: [:])
        XCTAssertFalse(SandboxDemoText.canProduce("sh", layout: cyr))
    }

    func test_canProduce_shiftLayerCounts() {
        let latin = Keymap(base: [1: "s"], shift: [1: "S"])
        XCTAssertTrue(SandboxDemoText.canProduce("S", layout: latin))
    }
}
