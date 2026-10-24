import Foundation

/// Deux pressions distinctes, pour la même action, dans une fenêtre courte.
struct EscapeConfirmation {
    enum Action { case cancel, leave }
    private var action: Action?
    private var deadline = Date.distantPast

    mutating func press(_ next: Action, at now: Date = Date()) -> Bool {
        if action == next && now < deadline {
            reset()
            return true
        }
        action = next
        deadline = now.addingTimeInterval(2.5)
        return false
    }

    mutating func reset() {
        action = nil
        deadline = .distantPast
    }
}
