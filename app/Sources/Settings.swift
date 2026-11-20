// The launcher's own settings (UserDefaults.standard): how the games are shown, and the face-button layouts handed to the game (DM_TOUCH_ABXY for the on-screen buttons,
// DM_PAD_ABXY for controllers; the controller one also sets the launcher's confirm / back). Unified (the default): one layout for both; off: each its own
import Foundation
import Combine

final class Settings: ObservableObject {
    static let shared = Settings()
    @Published var view: String { didSet { save(view, "nxl.view") } }            // "list" / "grid"
    @Published var unified: Bool { didSet { save(unified, "nxl.unified") } }     // one face-button layout for touch and controllers
    @Published var abxy: String { didSet { save(abxy, "nxl.abxy") } }            // "nintendo" / "xbox": the unified layout
    @Published var touchAbxy: String { didSet { save(touchAbxy, "nxl.touchAbxy") } }
    @Published var padAbxy: String { didSet { save(padAbxy, "nxl.padAbxy") } }
    @Published var language: String { didSet { save(language, "nxl.language") } }   // "ko" / "en": the launcher's text and the game names (default: the iPhone's language)
    var touchLayout: String { unified ? abxy : touchAbxy }
    var padLayout: String { unified ? abxy : padAbxy }
    private func save(_ v: Any, _ k: String) { UserDefaults.standard.set(v, forKey: k) }
    private init() {
        let d = UserDefaults.standard
        view = d.string(forKey: "nxl.view") ?? "grid"
        unified = d.object(forKey: "nxl.unified") as? Bool ?? true
        let a = d.string(forKey: "nxl.abxy") ?? "nintendo"
        abxy = a
        touchAbxy = d.string(forKey: "nxl.touchAbxy") ?? a   // turning unified off starts both from the unified choice
        padAbxy = d.string(forKey: "nxl.padAbxy") ?? a
        language = d.string(forKey: "nxl.language") ?? ((Locale.preferredLanguages.first ?? "").hasPrefix("ko") ? "ko" : "en")
    }
    // The options panel's rows, in order (the controller walks them)
    enum Row { case view, unified, abxy, touch, pad, language }
    var rows: [Row] { (unified ? [.view, .unified, .abxy] : [.view, .unified, .touch, .pad]) + [.language] }
    func flip(_ r: Row) {
        let other: (String) -> String = { $0 == "xbox" ? "nintendo" : "xbox" }
        switch r {
        case .view: view = view == "grid" ? "list" : "grid"
        case .unified: unified.toggle(); if !unified { touchAbxy = abxy; padAbxy = abxy }
        case .abxy: abxy = other(abxy)
        case .touch: touchAbxy = other(touchAbxy)
        case .pad: padAbxy = other(padAbxy)
        case .language: language = language == "ko" ? "en" : "ko"
        }
    }
}

func L(_ en: String, _ k: String) -> String { Settings.shared.language == "ko" ? k : en }
