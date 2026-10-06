import Carbon

/// Raccourci global via Carbon : aucune permission d'accessibilité requise,
/// et zéro coût tant que la touche n'est pas pressée.
final class HotKey {
    static var onPress: (() -> Void)?
    private static var handlerInstalled = false
    private var ref: EventHotKeyRef?

    var isRegistered: Bool { ref != nil }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        unregister()
        if !Self.handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                HotKey.onPress?()
                return noErr
            }, 1, &spec, nil, nil)
            Self.handlerInstalled = true
        }
        let id = EventHotKeyID(signature: OSType(0x484C_4F31), id: 1)
        guard RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr else {
            ref = nil
            return false
        }
        return true
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}

struct HotkeyChoice {
    let id: String
    let label: String
    let keyCode: UInt32
    let modifiers: UInt32
    var note: String? = nil
}

enum Prefs {
    static let hotkeys: [HotkeyChoice] = [
        HotkeyChoice(id: "cmd-space", label: "⌘ Espace", keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey),
                     note: "Le raccourci Spotlight (et celui de Raycast/Alfred) doit être désactivé"),
        HotkeyChoice(id: "opt-space", label: "⌥ Espace", keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)),
        HotkeyChoice(id: "ctrl-space", label: "⌃ Espace", keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey)),
        HotkeyChoice(id: "opt-cmd-space", label: "⌥⌘ Espace", keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey | cmdKey)),
        HotkeyChoice(id: "shift-cmd-space", label: "⇧⌘ Espace", keyCode: UInt32(kVK_Space), modifiers: UInt32(shiftKey | cmdKey)),
    ]

    static var hotkey: HotkeyChoice {
        get {
            let id = UserDefaults.standard.string(forKey: "hotkey")
            return hotkeys.first { $0.id == id } ?? hotkeys[0]
        }
        set { AppSettings.shared.hotkeyID = newValue.id }
    }
}
