import XCTest
@testable import ShiftHappensCore

final class SettingsStoreTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsStoreTests")
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
        super.tearDown()
    }

    func test_loadReturnsEmptySettingsWhenNothingStored() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.load(), AppSettings(enabledSourceIDs: []))
    }

    func test_saveThenLoadRoundTrip() {
        let store = SettingsStore(defaults: defaults)
        let settings = AppSettings(enabledSourceIDs: ["com.apple.keylayout.US", "com.apple.keylayout.Ukrainian"])
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func test_corruptDataLoadsAsEmpty() {
        defaults.set(Data("not json".utf8), forKey: "AppSettings")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.load(), AppSettings(enabledSourceIDs: []))
    }

    func test_legacySettingsWithoutRestoreFlag_decodeWithDefaults() {
        // Settings written before restoreClipboardAfterFix existed must still decode,
        // keeping the saved languages and defaulting the flag to false.
        let legacyJSON = #"{"enabledSourceIDs":["com.apple.keylayout.US"]}"#
        defaults.set(Data(legacyJSON.utf8), forKey: "AppSettings")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(
            store.load(),
            AppSettings(enabledSourceIDs: ["com.apple.keylayout.US"], restoreClipboardAfterFix: false)
        )
    }

    func test_restoreClipboardFlag_roundTrip() {
        let store = SettingsStore(defaults: defaults)
        let settings = AppSettings(enabledSourceIDs: ["a"], restoreClipboardAfterFix: true)
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func test_hotkeyConfig_roundTrip() {
        let store = SettingsStore(defaults: defaults)
        let settings = AppSettings(
            enabledSourceIDs: ["a"],
            hotkey: HotkeyConfig(keyCode: 15, modifiers: 0x400 | 0x800) // ⌃⌥
        )
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func test_defaultHotkeyIsStandard() {
        XCTAssertEqual(AppSettings().hotkey, nil)
        XCTAssertEqual(HotkeyConfig.standard.keySymbol, "K")
        XCTAssertEqual(HotkeyConfig.standard.modifierSymbols, ["⌥", "⌘"])
    }
}
