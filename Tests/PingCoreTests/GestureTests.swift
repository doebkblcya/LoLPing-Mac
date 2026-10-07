import Foundation
import CoreGraphics
import PingCore

private var failures = 0
private var assertions = 0
private func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    assertions += 1
    if actual != expected {
        failures += 1
        print("FAIL \(file):\(line): \(actual) != \(expected)")
    }
}

final class GestureTests {
    let anchor = CGPoint(x: 600, y: 400)

    func open(_ machine: GestureMachine, at point: CGPoint? = nil) {
        let point = point ?? anchor
        XCTAssertEqual(machine.leftMouseDown(.option, at: point, otherInputHeld: false), [.show(point)])
    }
    func testEightDirectionsAndCentralDeadZone() {
        let vectors: [CGPoint] = [.init(x: 0,y: 100), .init(x: 100,y: 100), .init(x: 100,y: 0), .init(x: 100,y: -100),
                                  .init(x: 0,y: -100), .init(x: -100,y: -100), .init(x: -100,y: 0), .init(x: -100,y: 100)]
        for (index, vector) in vectors.enumerated() {
            XCTAssertEqual(WheelGeometry.selection(at: vector, center: .zero, deadZone: WheelGeometry.centerRadius), PingKind.wheel[index])
        }
        XCTAssertEqual(WheelGeometry.selection(at: CGPoint(x: 66, y: 0), center: .zero, deadZone: WheelGeometry.centerRadius), .generic)
        XCTAssertEqual(WheelGeometry.selection(at: CGPoint(x: 67, y: 0), center: .zero, deadZone: WheelGeometry.centerRadius), .onMyWay)
    }
    func testOptionAloneAndUnmodifiedClickDoNothing() {
        let machine = GestureMachine()
        XCTAssertEqual(machine.flagsChanged(.option), [])
        XCTAssertEqual(machine.moved(to: CGPoint(x: 500, y: 400)), [])
        XCTAssertEqual(machine.phase, .idle)
        XCTAssertEqual(machine.flagsChanged([]), [])
        XCTAssertEqual(machine.leftMouseDown([], at: anchor, otherInputHeld: false), [])
        XCTAssertEqual(machine.leftMouseUp([], at: anchor), [])
    }
    func testReleaseCommitsExactlyOnceAtOriginalAnchor() {
        let machine = GestureMachine(); open(machine)
        let release = CGPoint(x: 500, y: 400)
        XCTAssertEqual(machine.moved(to: release), [.hover(.missing, angle: -.pi/2)])
        XCTAssertEqual(machine.leftMouseUp(.option, at: release), [.dismiss, .commit(.missing, anchor)])
        XCTAssertEqual(machine.leftMouseUp(.option, at: release), [])
        XCTAssertEqual(machine.flagsChanged([]), [])
        XCTAssertEqual(machine.phase, .idle)
    }
    func testReleaseUsesLatestPosition() {
        let machine = GestureMachine(); open(machine)
        _ = machine.moved(to: CGPoint(x: 600, y: 500))
        XCTAssertEqual(machine.leftMouseUp(.option, at: CGPoint(x: 500, y: 400)), [.dismiss, .commit(.missing, anchor)])
    }
    func testOptionReleaseCancelsWithoutCommit() {
        let machine = GestureMachine(); open(machine)
        XCTAssertEqual(machine.flagsChanged([]), [.hide])
        XCTAssertEqual(machine.phase, .blocked)
        XCTAssertEqual(machine.flagsChanged(.option), [])
        XCTAssertEqual(machine.moved(to: CGPoint(x: 500, y: 400)), [])
        XCTAssertEqual(machine.leftMouseDown(.option, at: anchor, otherInputHeld: false), [])
        XCTAssertEqual(machine.leftMouseUp(.option, at: anchor), [])
        open(machine)
        // A release lacking Option must cancel even without a flagsChanged event.
        XCTAssertEqual(machine.leftMouseUp([], at: anchor), [.hide])
        XCTAssertEqual(machine.phase, .idle)
    }
    func testRepeatedDragsCanKeepOptionHeld() {
        let machine = GestureMachine()
        for _ in 0..<3 {
            open(machine)
            XCTAssertEqual(machine.leftMouseUp(.option, at: anchor), [.dismiss, .commit(.generic, anchor)])
            XCTAssertEqual(machine.phase, .idle)
        }
    }
    func testCancellationRequiresLeftRelease() {
        let machine = GestureMachine(); open(machine)
        XCTAssertEqual(machine.cancel(), [.hide])
        XCTAssertEqual(machine.cancel(), [])
        XCTAssertEqual(machine.flagsChanged([]), [])
        XCTAssertEqual(machine.flagsChanged(.option), [])
        XCTAssertEqual(machine.leftMouseDown(.option, at: anchor, otherInputHeld: false), [])
        XCTAssertEqual(machine.leftMouseUp(.option, at: anchor), [])
        open(machine)
    }
    func testExtraModifiersDoNotTriggerAndCancelAnOpenWheel() {
        for extra: Modifiers in [.control, .command, .shift] {
            let machine = GestureMachine()
            XCTAssertEqual(machine.leftMouseDown([.option, extra], at: anchor, otherInputHeld: false), [])
            open(machine)
            XCTAssertEqual(machine.flagsChanged([.option, extra]), [.hide])
            XCTAssertEqual(machine.leftMouseUp(.option, at: anchor), [])
        }
    }
    func testExistingInputDoesNotTrigger() {
        let machine = GestureMachine()
        XCTAssertEqual(machine.leftMouseDown(.option, at: anchor, otherInputHeld: true), [])
        XCTAssertEqual(machine.phase, .idle)
        // Enabling while the left button is down cannot take over an existing drag.
        machine.reset(blockUntilRelease: true)
        XCTAssertEqual(machine.flagsChanged(.option), [])
        XCTAssertEqual(machine.moved(to: anchor), [])
        XCTAssertEqual(machine.leftMouseDown(.option, at: anchor, otherInputHeld: false), [])
        XCTAssertEqual(machine.leftMouseUp(.option, at: anchor), [])
        open(machine)
    }
    func testResetCannotCommit() {
        let machine = GestureMachine(); open(machine)
        machine.reset()
        XCTAssertEqual(machine.leftMouseUp(.option, at: anchor), [])
        XCTAssertEqual(machine.phase, .idle)
    }
    func testEdgeClampingPreservesActualPingLocation() {
        let edge = CGPoint(x: -1915, y: 1080)
        let display = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let center = WheelGeometry.clampedCenter(anchor: edge, frame: display, radius: 150)
        XCTAssertEqual(center, CGPoint(x: -1770, y: 930))
        let machine = GestureMachine(); open(machine, at: edge)
        XCTAssertEqual(machine.setWheelCenter(center), [])
        // No dragging at an edge still produces the ordinary Ping.
        XCTAssertEqual(machine.leftMouseUp(.option, at: edge), [.dismiss, .commit(.generic, edge)])
        open(machine, at: edge)
        _ = machine.setWheelCenter(center)
        let release = CGPoint(x: center.x+90, y: center.y)
        _ = machine.moved(to: release)
        XCTAssertEqual(machine.leftMouseUp(.option, at: release), [.dismiss, .commit(.onMyWay, edge)])
    }
    func testContinuousDirectionAndCenterReset() {
        let machine = GestureMachine(); open(machine)
        let first = CGPoint(x: 600, y: 500), second = CGPoint(x: 610, y: 500)
        XCTAssertEqual(machine.moved(to: first), [.hover(.retreat, angle: 0)])
        XCTAssertEqual(machine.moved(to: second), [.hover(.retreat, angle: atan2(10, 100))])
        XCTAssertEqual(machine.selected, .retreat)
        let center = CGPoint(x: 600, y: 466)
        XCTAssertEqual(machine.moved(to: center), [.hover(.generic, angle: nil)])
        XCTAssertEqual(machine.leftMouseUp(.option, at: center), [.dismiss, .commit(.generic, anchor)])
        XCTAssertEqual(machine.moved(to: first), [])
    }
    func testScaledCenterMatchesVisualCircle() {
        for scale: CGFloat in [0.75, 1, 1.5] {
            let machine = GestureMachine(); machine.deadZone = WheelGeometry.centerRadius*scale; open(machine)
            XCTAssertEqual(machine.moved(to: CGPoint(x: anchor.x+66*scale, y: anchor.y)), [.hover(.generic, angle: nil)])
            XCTAssertEqual(machine.moved(to: CGPoint(x: anchor.x+66*scale+0.01, y: anchor.y)), [.hover(.onMyWay, angle: .pi/2)])
        }
    }
}

@main
enum Checks {
    static func main() {
        let test = GestureTests()
        let scenarios: [(String, () -> Void)] = [
            ("八向选择与中央区域", test.testEightDirectionsAndCentralDeadZone),
            ("Option 单键与普通点击不触发", test.testOptionAloneAndUnmodifiedClickDoNothing),
            ("左键释放单次发送及原始落点", test.testReleaseCommitsExactlyOnceAtOriginalAnchor),
            ("松开左键使用最新位置", test.testReleaseUsesLatestPosition),
            ("提前松开 Option 取消", test.testOptionReleaseCancelsWithoutCommit),
            ("保持 Option 连续拖动", test.testRepeatedDragsCanKeepOptionHeld),
            ("取消后必须松开左键", test.testCancellationRequiresLeftRelease),
            ("额外修饰键保护", test.testExtraModifiersDoNotTriggerAndCancelAnOpenWheel),
            ("现有拖动或按键保护", test.testExistingInputDoesNotTrigger),
            ("关闭后不再提交", test.testResetCannotCommit),
            ("外接屏坐标与贴边落点", test.testEdgeClampingPreservesActualPingLocation),
            ("同扇区方向更新与中央复位", test.testContinuousDirectionAndCenterReset),
            ("缩放后中心判定与圆圈一致", test.testScaledCenterMatchesVisualCircle)
        ]
        for (name, scenario) in scenarios {
            let before = failures
            scenario()
            print("\(failures == before ? "PASS" : "FAIL") \(name)")
        }
        print("\(scenarios.count) scenarios, \(assertions) assertions, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
