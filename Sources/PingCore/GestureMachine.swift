import Foundation
import CoreGraphics

/// Pure state machine. Platform code handles clocks, permissions and rendering.
public final class GestureMachine {
    public enum Phase: Equatable { case idle, open, blocked }
    public enum Action: Equatable {
        case show(CGPoint), hover(PingKind, angle: CGFloat?), hide, dismiss, commit(PingKind, CGPoint)
    }
    public private(set) var phase: Phase = .idle
    public private(set) var selected: PingKind = .generic
    public private(set) var anchor: CGPoint = .zero
    public private(set) var currentModifiers: Modifiers = []
    public var deadZone: CGFloat = WheelGeometry.centerRadius
    private var center: CGPoint = .zero
    private var pointer: CGPoint = .zero
    public init() {}

    public func flagsChanged(_ flags: Modifiers) -> [Action] {
        currentModifiers = flags
        // Option alone does nothing. Releasing it or adding another modifier
        // cancels the drag; the left button must be released before retrying.
        if phase == .open, flags != .option { return cancel() }
        return []
    }

    public func leftMouseDown(_ flags: Modifiers, at point: CGPoint, otherInputHeld: Bool) -> [Action] {
        currentModifiers = flags
        guard phase == .idle, flags == .option, !otherInputHeld else { return [] }
        anchor = point; center = point; pointer = point; selected = .generic
        phase = .open
        return [.show(anchor)]
    }

    public func leftMouseUp(_ flags: Modifiers, at point: CGPoint) -> [Action] {
        currentModifiers = flags
        guard phase == .open else {
            phase = .idle
            return []
        }
        guard flags == .option else {
            let actions = cancel()
            phase = .idle
            return actions
        }
        // Use the release position even if the last drag event was coalesced.
        // With no movement, an inward-clamped wheel still sends a normal Ping.
        if point != pointer { _ = moved(to: point) }
        phase = .idle
        return [.dismiss, .commit(selected, anchor)]
    }

    public func setWheelCenter(_ point: CGPoint) -> [Action] {
        center = point
        // At an edge the wheel moves inwards, but the original Ping anchor stays fixed.
        guard hypot(pointer.x - anchor.x, pointer.y - anchor.y) > 4 else { return [] }
        return moved(to: pointer)
    }

    public func moved(to point: CGPoint) -> [Action] {
        pointer = point
        guard phase == .open else { return [] }
        let next = WheelGeometry.selection(at: point, center: center, deadZone: deadZone)
        selected = next
        return [.hover(next, angle: WheelGeometry.direction(at: point, center: center, deadZone: deadZone))]
    }

    public func cancel() -> [Action] {
        let hadGesture = phase == .open
        if hadGesture { phase = .blocked }
        selected = .generic
        return hadGesture ? [.hide] : []
    }

    public func reset(blockUntilRelease: Bool = false) {
        phase = blockUntilRelease ? .blocked : .idle
        selected = .generic
        currentModifiers = []
    }
}
