//
//  SceneDelegate.swift
//  FittedSheets
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    // TEMP (debugging): launch straight into the leading-panel demo when the
    // AUTO_LEADING_PANEL environment variable is set, so automated runs can skip the menu.
    private var didAutoOpen = false

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard ProcessInfo.processInfo.environment["AUTO_LEADING_PANEL"] != nil,
              !didAutoOpen,
              let root = window?.rootViewController else { return }
        didAutoOpen = true
        LeadingPanelDemo.openDemo(from: root, in: nil)
    }
}
