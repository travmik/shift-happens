import XCTest
@testable import ShiftHappensCore

/// Smoke test for the UCKeyTranslate extraction path — runs on a real Mac with real layouts.
final class KeymapProviderTests: XCTestCase {

    func test_extractsKeymapForCurrentLayout() throws {
        let inputSource = InputSourceService()
        let currentID = try XCTUnwrap(inputSource.currentLayoutID(), "no current input source")
        let provider = KeymapProvider()
        let keymap = try XCTUnwrap(provider.keymap(forSourceID: currentID), "keymap extraction failed for \(currentID)")

        // A real layout produces a substantial table on both layers.
        XCTAssertGreaterThan(keymap.base.count, 20)
        XCTAssertGreaterThan(keymap.shift.count, 0)
    }

    func test_shiftLayerContainsUppercaseOfBaseLetters() throws {
        // Regression guard: extracting the wrong UCKeyTranslate modifier state once
        // produced a shift layer that was a copy of the base layer, so every capital
        // letter passed through untranslated.
        let inputSource = InputSourceService()
        let currentID = try XCTUnwrap(inputSource.currentLayoutID())
        let keymap = try XCTUnwrap(KeymapProvider().keymap(forSourceID: currentID))

        let letterKeys = keymap.base.filter { $0.value.isLowercase && String($0.value) != String($0.value).uppercased() }
        XCTAssertFalse(letterKeys.isEmpty, "layout has no lowercase letter keys to check")
        for (keyCode, char) in letterKeys {
            XCTAssertEqual(keymap.shift[keyCode].map(String.init), String(char).uppercased(),
                           "shift layer wrong at keyCode \(keyCode): expected \(String(char).uppercased())")
        }
    }
}
