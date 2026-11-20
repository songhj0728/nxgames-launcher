// The games in Frameworks/ and how one is started.
import UIKit
import Darwin

struct Game: Identifiable {
    let bundle: Bundle
    var id: String { bundle.bundlePath }
    var folder: String { (bundle.bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".framework", with: "") }
    var bundleID: String { bundle.bundleIdentifier ?? folder }
    // The name in the iPhone's language: the framework's <lang>.lproj/InfoPlist.strings (the launcher allows mixed localizations)
    // The name in the launcher's language: the framework's <lang>.lproj/InfoPlist.strings (game_names.py writes one per language the game has), else its default name
    var name: String {
        let url = bundle.bundleURL.appendingPathComponent("\(Settings.shared.language).lproj/InfoPlist.strings")
        if let d = try? Data(contentsOf: url), let p = try? PropertyListSerialization.propertyList(from: d, format: nil) as? [String: Any], let n = p["CFBundleDisplayName"] as? String { return n }
        return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? folder
    }
    var version: String { (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "" }
    var icon: UIImage? {
        if let i = UIImage(named: "AppIcon", in: bundle, compatibleWith: nil) { return i }
        guard let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any], let p = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = p["CFBundleIconFiles"] as? [String], let last = files.last else { return nil }
        return UIImage(named: last, in: bundle, compatibleWith: nil)
    }
    // Game data installed once into the data container (assemble.sh): Library/NXRes/<game bundle ID>
    var resDir: URL { FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("NXRes").appendingPathComponent(bundleID) }
    var docDir: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(bundleID) }
    var hasData: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: resDir.appendingPathComponent("romfs.img").path) || fm.fileExists(atPath: bundle.bundleURL.appendingPathComponent("romfs.img").path)
    }
    var settingsFile: [Setting] {
        guard let d = try? Data(contentsOf: bundle.bundleURL.appendingPathComponent("dm/launcher.json")), let f = try? JSONDecoder().decode(SettingsFile.self, from: d) else { return [] }
        return f.settings
    }
    var defaults: UserDefaults { UserDefaults(suiteName: bundleID) ?? .standard }   // the same store the game's own launcher code uses (Launcher.swift dmDefaults)

    static func all() -> [Game] {
        guard let dir = Bundle.main.privateFrameworksURL, let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.filter { $0.hasSuffix(".framework") }.compactMap { Bundle(url: dir.appendingPathComponent($0)) }
            .filter { $0.object(forInfoDictionaryKey: "DMLanguage") != nil }.map(Game.init).sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

enum Boot {
    static var focus: ((Int32) -> Void)?
    // The installed data for the game's boot (main.m boot_env sets these only when unset): romfs_locate takes Documents/<id>/romfs.img, a hard link to the installed image
    static func useInstalledData(_ g: Game) {
        let fm = FileManager.default, res = g.resDir
        guard fm.fileExists(atPath: res.path) else { return }
        var parent = res.deletingLastPathComponent(); var rv = URLResourceValues(); rv.isExcludedFromBackup = true; try? parent.setResourceValues(rv)
        try? fm.createDirectory(at: g.docDir, withIntermediateDirectories: true)
        let img = res.appendingPathComponent("romfs.img"), lnk = g.docDir.appendingPathComponent("romfs.img")
        if fm.fileExists(atPath: img.path) {
            var a = stat(), l = stat()
            if stat(lnk.path, &l) != 0 || stat(img.path, &a) != 0 || a.st_ino != l.st_ino { try? fm.removeItem(at: lnk); link(img.path, lnk.path) }
        }
        try? fm.removeItem(at: res.appendingPathComponent("msl"))   // shader libraries stay in the bundle (a partial copy from an interrupted transfer must not be used)
        for (d, env) in [("pso", "DM_PSO_BUNDLE"), ("aoc", "DM_AOC_DIR")] where fm.fileExists(atPath: res.appendingPathComponent(d).path) {
            setenv(env, res.appendingPathComponent(d).path, 1)
        }
    }
    // dlopen the game and boot it with its own Documents folder; returns its root view controller, or an error
    enum Started { case ok(UIViewController), failed(String) }
    static func start(_ g: Game) -> Started {
        guard let exe = g.bundle.executablePath, let h = dlopen(exe, RTLD_NOW | RTLD_LOCAL) else { return .failed(String(cString: dlerror())) }
        guard let b = dlsym(h, "dm_framework_boot"), let r = dlsym(h, "dm_framework_root") else { return .failed("entry points missing") }
        typealias BootFn = @convention(c) (UnsafePointer<CChar>) -> Int32
        typealias RootFn = @convention(c) () -> Unmanaged<UIViewController>
        typealias FocusFn = @convention(c) (Int32) -> Void
        if let f = dlsym(h, "dm_framework_focus") { let fn = unsafeBitCast(f, to: FocusFn.self); focus = { fn($0) } }
        _ = unsafeBitCast(b, to: BootFn.self)(g.docDir.path)
        return .ok(unsafeBitCast(r, to: RootFn.self)().takeUnretainedValue())
    }
}
