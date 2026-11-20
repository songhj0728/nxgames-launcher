// Which screen is up, the controller focus on it, and starting a game
import UIKit
import Combine

enum Screen { case home, game(Game, LauncherModel) }
enum GameItem: Hashable { case play, row(String), reset, diag }

final class Nav: ObservableObject {
    let pad = Pad()
    let games = Game.all()
    weak var window: UIWindow?
    @Published var screen: Screen = .home
    @Published var homeFocus = 0
    @Published var cols = 1                 // grid columns now (for up / down)
    @Published var gameFocus: GameItem = .play
    @Published var options = false          // the launcher's settings panel
    @Published var optionFocus = 0
    @Published var message: String?

    init() {
        pad.handler = { [weak self] in self?.handle($0) }
        pad.start()
    }

    // A game's env files (Documents/<id>/env.txt first, then the bundle's dm/env.txt, as main.m reads them) fix their settings: the settings screen shows them locked and
    // Play leaves them alone. The keys of the game opened before are taken back out first
    private var envKeys: [String] = []
    private func loadEnvFiles(_ g: Game) {
        for k in envKeys { unsetenv(k) }; envKeys = []
        for url in [g.docDir.appendingPathComponent("env.txt"), g.bundle.bundleURL.appendingPathComponent("dm/env.txt")] {
            guard let txt = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for raw in txt.split(whereSeparator: \.isNewline) {
                let ln = raw.trimmingCharacters(in: .whitespaces); guard !ln.hasPrefix("#"), let eq = ln.firstIndex(of: "="), eq != ln.startIndex else { continue }
                let k = String(ln[..<eq]); if envKeys.contains(k) { continue }
                setenv(k, String(ln[ln.index(after: eq)...]), 1); envKeys.append(k)
            }
        }
        setenv("DM_ENV_FILE_KEYS", envKeys.joined(separator: " "), 1)
    }
    // One-time GPU diagnosis (per game): the next start times every pass of one frame in every 300 (DM_NVN_GPUPROF=every:300: "[gpuprof]" lines in the game's log, with what each
    // pass loads and stores). It runs on the Metal 4 path as usual, so the game plays about as fast as without it (DM_NVN_PASSGPU's stage-boundary counters gave nothing on an iPhone).
    // Turned off again once the game starts
    func diagKey(_ g: Game) -> String { "nxl.diag." + g.bundleID }

    func open(_ g: Game) {
        loadEnvFiles(g)
        screen = .game(g, LauncherModel(g.settingsFile, defaults: g.defaults)); gameFocus = .play
    }
    func back() { screen = .home; message = nil }

    // Play: the settings go into the environment (and the game's own store), the game's own settings screen is skipped (DM_LAUNCHER=0: it applies the same saved choices),
    // the installed data is pointed to, and the game takes the window
    func play(_ g: Game, model: LauncherModel?) {
        guard g.hasData else { message = L("This game's data is not installed.", "이 게임의 데이터가 설치되지 않았습니다."); return }
        if let m = model { m.apply() } else { LauncherModel(g.settingsFile, defaults: g.defaults).applySaved() }
        if UserDefaults.standard.bool(forKey: diagKey(g)) {
            setenv("DM_NVN_GPUPROF", "every:300", 1)
            UserDefaults.standard.set(false, forKey: diagKey(g)); fputs("launcher: GPU diagnosis on for this run (DM_NVN_GPUPROF=every:300)\n", stderr)
        }
        setenv("DM_LAUNCHER", "0", 1)
        setenv("DM_PAD_ABXY", Settings.shared.padLayout, 1); setenv("DM_TOUCH_ABXY", Settings.shared.touchLayout, 1)
        Boot.useInstalledData(g)
        switch Boot.start(g) {
        case .ok(let vc): pad.stop(); pad.handler = nil; window?.rootViewController = vc
        case .failed(let e): message = L("The game could not be loaded: ", "게임을 불러오지 못했습니다: ") + e
        }
    }

    func gameItems(_ m: LauncherModel) -> [GameItem] {
        [.play] + m.sections.flatMap { m.rows(in: $0) }.map { .row($0.env) } + [.reset, .diag]
    }

    private func handle(_ e: PadEvent) {
        if options { optionsEvent(e); return }
        switch screen {
        case .home: homeEvent(e)
        case .game(let g, let m): gameEvent(e, g, m)
        }
    }
    private func homeEvent(_ e: PadEvent) {
        let n = games.count; guard n > 0 else { if e == .start { options = true }; return }
        let step = Settings.shared.view == "grid" ? max(cols, 1) : 1
        switch e {
        case .up: homeFocus = max(homeFocus - step, 0)
        case .down: homeFocus = min(homeFocus + step, n - 1)
        case .left: if Settings.shared.view == "grid" { homeFocus = max(homeFocus - 1, 0) }
        case .right: if Settings.shared.view == "grid" { homeFocus = min(homeFocus + 1, n - 1) }
        case .confirm: open(games[min(homeFocus, n - 1)])
        case .x: Settings.shared.view = Settings.shared.view == "grid" ? "list" : "grid"
        case .start: options = true; optionFocus = 0
        default: break
        }
    }
    private func gameEvent(_ e: PadEvent, _ g: Game, _ m: LauncherModel) {
        let items = gameItems(m); let i = items.firstIndex(of: gameFocus) ?? 0
        switch e {
        case .up: gameFocus = items[max(i - 1, 0)]
        case .down: gameFocus = items[min(i + 1, items.count - 1)]
        case .left, .right: if case .row(let env) = gameFocus { adjust(m, env, e == .right ? 1 : -1, wrap: false) }
        case .confirm:
            switch gameFocus {
            case .play: play(g, model: m)
            case .reset: m.reset()
            case .diag: UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: diagKey(g)), forKey: diagKey(g)); objectWillChange.send()
            case .row(let env): adjust(m, env, 1, wrap: true)
            }
        case .start: play(g, model: m)
        case .back: back()
        default: break
        }
    }
    // One step of a setting: a toggle flips, a choice moves to the next / previous option, a range by its step (confirm leaves a range alone)
    private func adjust(_ m: LauncherModel, _ env: String, _ d: Int, wrap: Bool) {
        guard let s = m.settings.first(where: { $0.env == env }), !m.fixed.contains(env) else { return }
        let v = m.values[env] ?? s.def
        switch s.kind {
        case "toggle": m.values[env] = v == s.onValue ? s.offValue : s.onValue
        case "choice":
            let opts = (s.options ?? []).map { $0[0] }; guard !opts.isEmpty else { return }
            let j = opts.firstIndex(of: v) ?? 0
            m.values[env] = opts[wrap ? (j + d + opts.count) % opts.count : min(max(j + d, 0), opts.count - 1)]
        case "range":
            if wrap { return }
            let st = s.step ?? 0.05, x = min(max((Double(v) ?? 1) + Double(d) * st, s.min ?? 0), s.max ?? 1)
            m.values[env] = String(format: "%.2f", x)
        default: break
        }
    }
    private func optionsEvent(_ e: PadEvent) {
        let st = Settings.shared, rows = st.rows
        switch e {
        case .up: optionFocus = max(optionFocus - 1, 0)
        case .down: optionFocus = min(optionFocus + 1, rows.count - 1)
        case .left, .right, .confirm: st.flip(rows[min(optionFocus, rows.count - 1)]); optionFocus = min(optionFocus, st.rows.count - 1)
        case .back, .start: options = false
        default: break
        }
    }
}
