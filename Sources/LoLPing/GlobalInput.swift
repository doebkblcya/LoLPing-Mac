import AppKit
import ApplicationServices
import PingCore

final class GlobalInput {
    enum StartError: LocalizedError {
        case permission, eventTap
        var errorDescription: String? {
            switch self {
            case .permission: return "请先在系统设置中允许 LoLPing 使用辅助功能。"
            case .eventTap: return "无法接收全局按键。请检查辅助功能权限；若系统要求输入监控权限，也请为 LoLPing 开启，然后重试。"
            }
        }
    }
    let machine = GestureMachine()
    var onAction: ((GestureMachine.Action) -> Void)?
    var onUnavailable: (() -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var listening = false
    private var keysDown: Set<Int64> = []
    private var swallowedKeys: Set<Int64> = []
    private var swallowedLeft = false
    private var swallowedRight = false
    private var recoveryAttempts = 0

    static var isTrusted: Bool { AXIsProcessTrusted() }
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func start(scale: Double) throws {
        stop()
        guard Self.isTrusted else { throw StartError.permission }
        machine.deadZone = WheelGeometry.centerRadius*scale
        machine.reset(blockUntilRelease: CGEventSource.buttonState(.combinedSessionState, button: .left))
        // A cancelled drag may still be draining its mouse-up after a restart.
        if let tap {
            listening = true
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }
        let types: [CGEventType] = [.flagsChanged, .keyDown, .keyUp, .mouseMoved,
                                   .leftMouseDown, .leftMouseUp, .leftMouseDragged,
                                   .rightMouseDown, .rightMouseUp, .rightMouseDragged,
                                   .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let input = Unmanaged<GlobalInput>.fromOpaque(context).takeUnretainedValue()
            return input.receive(type, event) ? nil : Unmanaged.passUnretained(event)
        }
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                            options: .defaultTap, eventsOfInterest: mask, callback: callback,
                                            userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            throw StartError.eventTap
        }
        tap = newTap
        listening = true
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: newTap, enable: true)
    }

    func stop() {
        listening = false
        keysDown.removeAll(); recoveryAttempts = 0
        machine.reset()
        // If we swallowed a down event, also swallow its remaining drag/up.
        // Disabling or changing size mid-drag must not leak it to other apps.
        if !hasSwallowedInput { removeTap() }
    }

    private var hasSwallowedInput: Bool { swallowedLeft || swallowedRight || !swallowedKeys.isEmpty }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }

    func cancelCurrent() {
        dispatch(machine.cancel())
    }
    func setWheelCenter(_ center: CGPoint) { dispatch(machine.setWheelCenter(center)) }

    private static func modifiers(_ flags: CGEventFlags) -> Modifiers {
        var result: Modifiers = []
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        return result
    }
    private func point(_ event: CGEvent) -> CGPoint {
        let mainTop = NSScreen.screens.first?.frame.maxY ?? 0
        return CGPoint(x: event.location.x, y: mainTop-event.location.y)
    }
    private func receive(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            cancelCurrent()
            recoveryAttempts += 1
            if recoveryAttempts <= 2, Self.isTrusted, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            else { DispatchQueue.main.async { [weak self] in self?.onUnavailable?() } }
            return false
        }
        recoveryAttempts = 0
        if !listening { return drain(type, event) }
        switch type {
        case .flagsChanged:
            dispatch(machine.flagsChanged(Self.modifiers(event.flags)))
        case .keyDown:
            let key = event.getIntegerValueField(.keyboardEventKeycode)
            keysDown.insert(key)
            let active = machine.phase == .open
            if swallowedKeys.contains(key) { return true }
            cancelCurrent()
            if active && key == 53 { swallowedKeys.insert(key); return true }
        case .keyUp:
            let key = event.getIntegerValueField(.keyboardEventKeycode)
            keysDown.remove(key)
            if swallowedKeys.remove(key) != nil { return true }
        case .mouseMoved:
            break
        case .leftMouseDown:
            if swallowedLeft { return true }
            let held = (NSEvent.pressedMouseButtons & ~1) != 0 || !keysDown.isEmpty
            let actions = machine.leftMouseDown(Self.modifiers(event.flags), at: point(event), otherInputHeld: held)
            swallowedLeft = machine.phase == .open
            dispatch(actions)
            return swallowedLeft
        case .leftMouseDragged:
            if swallowedLeft {
                dispatch(machine.flagsChanged(Self.modifiers(event.flags)))
                dispatch(machine.moved(to: point(event)))
                return true
            }
        case .leftMouseUp:
            let swallow = swallowedLeft
            swallowedLeft = false
            dispatch(machine.leftMouseUp(Self.modifiers(event.flags), at: point(event)))
            return swallow
        case .rightMouseDown:
            let active = machine.phase == .open
            cancelCurrent()
            if active { swallowedRight = true; return true }
        case .rightMouseUp:
            if swallowedRight { swallowedRight = false; return true }
        case .rightMouseDragged:
            if swallowedRight { return true }
        case .otherMouseDown, .otherMouseDragged, .scrollWheel:
            cancelCurrent()
        default: break
        }
        return false
    }

    private func drain(_ type: CGEventType, _ event: CGEvent) -> Bool {
        var swallow = false
        switch type {
        case .leftMouseDown, .leftMouseDragged: swallow = swallowedLeft
        case .leftMouseUp: swallow = swallowedLeft; swallowedLeft = false
        case .rightMouseDown, .rightMouseDragged: swallow = swallowedRight
        case .rightMouseUp: swallow = swallowedRight; swallowedRight = false
        case .keyDown: swallow = swallowedKeys.contains(event.getIntegerValueField(.keyboardEventKeycode))
        case .keyUp: swallow = swallowedKeys.remove(event.getIntegerValueField(.keyboardEventKeycode)) != nil
        default: break
        }
        if !hasSwallowedInput { removeTap() }
        return swallow
    }

    private func dispatch(_ actions: [GestureMachine.Action]) {
        actions.forEach { onAction?($0) }
    }
}
