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

    func test_generate_mapsTextThroughLayouts() {
        let result = SandboxDemoText.generate(text: "shift happens",
                                              active: latinKeymap(),
                                              next: cyrillicKeymap())
        XCTAssertEqual(result, "ыршае рфззуты")
    }

    func test_generate_returnsNilWhenActiveKeymapMissing() {
        XCTAssertNil(SandboxDemoText.generate(text: "shift happens", active: nil, next: cyrillicKeymap()))
    }

    func test_generate_returnsNilWhenNextKeymapMissing() {
        XCTAssertNil(SandboxDemoText.generate(text: "shift happens", active: latinKeymap(), next: nil))
    }

    func test_generate_returnsNilWhenTranslationIsNoOp() {
        // Same layout twice: every char maps to itself → unusable demo.
        XCTAssertNil(SandboxDemoText.generate(text: "shift happens",
                                              active: latinKeymap(),
                                              next: latinKeymap()))
    }

    func test_generate_mapsCyrillicToLatinForTheInverseDirection() {
        let result = SandboxDemoText.generate(text: "ыршае рфззуты",
                                              active: cyrillicKeymap(),
                                              next: latinKeymap())
        XCTAssertEqual(result, "shift happens")
    }
}
