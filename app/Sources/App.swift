// NX Games: one app holding several nxnative games, each a framework in Frameworks/ (built with DM_AS_DYLIB=1). The home screen lists them (list or grid); a game's settings
// screen (the game's own launcher.json, drawn with the same LauncherSettings / LauncherRow code the game uses) comes before any of its code is loaded, so Back still works;
// Play applies the settings, dlopens the game and hands the window to it. Only one game per run: to switch after playing, close the app. Everything is usable with a controller.
import UIKit
import SwiftUI

func dmDefaults() -> UserDefaults { .standard }   // LauncherSettings.swift's default store; every game here passes its own

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ a: UIApplication, configurationForConnecting s: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default", sessionRole: s.role)
    }
}

@objc(NXLScene)   // Info.plist names the scene delegate NXLScene: without this the Swift class is NXLauncher.NXLScene, no scene connects and the screen stays black
final class NXLScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        let w = UIWindow(windowScene: scene as! UIWindowScene)
        let nav = Nav()
        nav.window = w
        let host = UIHostingController(rootView: RootView(nav: nav, pad: nav.pad))
        host.view.backgroundColor = .systemGroupedBackground
        w.rootViewController = host
        w.makeKeyAndVisible()
        window = w
        fputs("launcher: window up, \(nav.games.count) games\n", stderr)
        if let name = ProcessInfo.processInfo.environment["NXL_GAME"], let g = nav.games.first(where: { $0.folder == name }) {   // testing: start that game with its saved settings
            DispatchQueue.main.async { nav.play(g, model: nil) }
        }
    }
    func sceneWillResignActive(_ s: UIScene) { Boot.focus?(0) }
    func sceneDidEnterBackground(_ s: UIScene) { Boot.focus?(1) }
    func sceneWillEnterForeground(_ s: UIScene) { Boot.focus?(2) }
    func sceneDidBecomeActive(_ s: UIScene) { Boot.focus?(3) }
}

@main
enum Main {
    static func main() { UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self)) }
}
