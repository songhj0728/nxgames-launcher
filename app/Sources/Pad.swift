// Controller input for the launcher's screens: polled 60 times a second (the game installs its own handlers once it runs, so nothing is left behind), turned into
// navigation events with key repeat. Confirm / back follow the controller face-button layout: Nintendo (by position: right confirms, bottom goes back) or Xbox (bottom confirms).
import GameController
import Combine

enum PadEvent { case up, down, left, right, confirm, back, start, x, y }

final class Pad: ObservableObject {
    var handler: ((PadEvent) -> Void)?
    @Published var connected = false
    private var timer: Timer?
    private var held: [PadEvent: Double] = [:]   // when each held event fires next
    private let first = 0.35, again = 0.09

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.poll() }
    }
    func stop() { timer?.invalidate(); timer = nil; held = [:] }

    private func poll() {
        let pads = GCController.controllers().compactMap { $0.extendedGamepad }
        if connected != !pads.isEmpty { connected = !pads.isEmpty }
        let xbox = Settings.shared.padLayout == "xbox"
        var now = Set<PadEvent>()
        for g in pads {
            let lx = g.leftThumbstick.xAxis.value, ly = g.leftThumbstick.yAxis.value
            if g.dpad.up.isPressed || ly > 0.5 { now.insert(.up) }
            if g.dpad.down.isPressed || ly < -0.5 { now.insert(.down) }
            if g.dpad.left.isPressed || lx < -0.5 { now.insert(.left) }
            if g.dpad.right.isPressed || lx > 0.5 { now.insert(.right) }
            if (xbox ? g.buttonA : g.buttonB).isPressed { now.insert(.confirm) }   // GameController names buttons by position: A bottom, B right
            if (xbox ? g.buttonB : g.buttonA).isPressed { now.insert(.back) }
            if g.buttonMenu.isPressed { now.insert(.start) }
            if (xbox ? g.buttonX : g.buttonY).isPressed { now.insert(.y) }     // Nintendo Y = left, Xbox X = left: the same physical button
            if (xbox ? g.buttonY : g.buttonX).isPressed { now.insert(.x) }     // top
        }
        let t = CACurrentMediaTime()
        for e in held.keys where !now.contains(e) { held[e] = nil }
        for e in now {
            let repeats = [.up, .down, .left, .right].contains(e)
            if let next = held[e] { if repeats && t >= next { held[e] = t + again; handler?(e) } }
            else { held[e] = repeats ? t + first : .infinity; handler?(e) }
        }
    }
}
