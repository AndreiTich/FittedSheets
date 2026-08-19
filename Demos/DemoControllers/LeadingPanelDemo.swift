//
//  LeadingPanelDemo.swift
//  FittedSheets
//
//  Demonstrates `SheetOptions.adaptiveInlineLayout`: the library owns the layout guide
//  and automatically switches between bottom-card and leading-panel modes.
//

import UIKit
import FittedSheets

class LeadingPanelDemo: UIViewController, Demoable {
    class var name: String { "Leading Panel (adaptiveInlineLayout)" }

    private var sheet: SheetViewController?
    private var panelOnTrailingEdge = false

    /// Height reserved at the top for the demo's own chrome (the Close button row).
    ///
    /// The adaptive panel pins to the container's safe area, so any top chrome the sheet must
    /// not cover has to be part of the safe area. This is the same pattern a real host app
    /// uses (e.g. reserving space for a floating search bar): extend `additionalSafeAreaInsets`
    /// by the chrome height, and pin the chrome itself with a compensating negative offset so
    /// it stays at the true top.
    private let topChromeHeight: CGFloat = 56

    class func openDemo(from parent: UIViewController, in view: UIView?) {
        let vc = LeadingPanelDemo()
        vc.modalPresentationStyle = .fullScreen
        parent.present(vc, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        additionalSafeAreaInsets.top = topChromeHeight
        setupMapPlaceholder()
        setupDismissButton()
        setupSideToggleButton()
        setupSheet()
    }

    private func setupMapPlaceholder() {
        let map = UIView()
        map.translatesAutoresizingMaskIntoConstraints = false
        map.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.3)
        view.addSubview(map)
        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupDismissButton() {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Close", for: .normal)
        button.addTarget(self, action: #selector(dismissDemo), for: .touchUpInside)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            // `additionalSafeAreaInsets.top` includes the chrome row this button lives in, so
            // subtract it back out to position the button at the true top of the window.
            button.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 16 - topChromeHeight),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        ])
    }

    private func setupSideToggleButton() {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Move panel", for: .normal)
        button.addTarget(self, action: #selector(togglePanelEdge), for: .touchUpInside)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 16 - topChromeHeight),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func setupSheet() {
        let content = SheetContentViewController()

        var options = SheetOptions(
            pullBarHeight: 20,
            useInlineMode: true,
            isRubberBandEnabled: true)
        options.shouldSnapToClosestSheetSize = true
        options.transitionOverflowType = .none

        var adaptive = AdaptiveInlineLayout()
        adaptive.regularWidthRule = .minimumContainerWidth(600)
        adaptive.panelWidth = 320
        adaptive.panelEdge = .leading
        adaptive.panelInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        adaptive.panelInsetReference = .safeArea
        adaptive.regularWidthCornerRadius = 16
        adaptive.regularWidthShadow = .standard
        options.adaptiveInlineLayout = adaptive

        let sheet = SheetViewController(
            controller: content,
            sizes: [.fixed(200), .percent(0.5), .fullscreen],
            options: options)
        sheet.allowGestureThroughOverlay = true
        sheet.overlayColor = .clear
        sheet.cornerRadius = 16
        sheet.gripColor = .secondaryLabel
        sheet.adaptiveCompactSizes = [.fixed(200), .percent(0.5), .fullscreen]
        sheet.adaptiveRegularWidthSizes = [.fullscreen]

        sheet.animateIn(to: view, in: self, size: .fixed(200))
        self.sheet = sheet
        Self.addSheetEventLogging(to: sheet)
    }

    @objc private func togglePanelEdge() {
        guard let sheet, var adaptive = sheet.adaptiveInlineLayout else { return }
        panelOnTrailingEdge.toggle()
        adaptive.panelEdge = panelOnTrailingEdge ? .trailing : .leading
        adaptive.regularWidthShadow = panelOnTrailingEdge ? .prominent : .standard
        sheet.updateAdaptiveInlineLayout(adaptive)
    }

    @objc private func dismissDemo() {
        dismiss(animated: true)
    }
}

private class SheetContentViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.backgroundColor = .systemBackground
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 40 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "Result \(indexPath.row + 1)"
        return cell
    }
}
