//
//  CollapseToZeroDemo.swift
//  FittedSheets
//
//  Demonstrates collapsing a sheet to a zero-height detent (`.percent(0)`) when the hosted
//  content has a required minimum height. Without the collapse-offscreen handling in
//  `SheetViewController`, Auto Layout has to break either the sheet's `height == 0` constraint
//  or the header's required height, and which one it drops is arbitrary — a strip of header can
//  survive at the bottom edge. With it, the content slides below the sheet's bottom edge instead.
//
//  The sheet also opts into `adaptiveInlineLayout`, so on a wide container (iPad, or a large
//  iPhone in landscape) the same screen shows the leading-panel variant and confirms the collapsed
//  content stays clipped beneath the inset card.
//

import UIKit
import FittedSheets

class CollapseToZeroDemo: UIViewController, Demoable {
    static var name: String { "Collapse to zero height" }

    static let headerHeight: CGFloat = 56

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.25)

        // Mirrors a host header that cannot shrink: required height and required pins to both
        // the top and bottom of its container.
        let header = UIView()
        header.backgroundColor = .systemRed
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let headerLabel = UILabel()
        headerLabel.text = "Required \(Int(Self.headerHeight))pt header"
        headerLabel.textColor = .white
        headerLabel.font = .boldSystemFont(ofSize: 15)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerLabel)

        let buttons = UIStackView(arrangedSubviews: [
            makeButton("Collapse (.percent(0))") { [weak self] in
                self?.sheetViewController?.resize(to: .percent(0))
            },
            makeButton("Resize to .fixed(200)") { [weak self] in
                self?.sheetViewController?.resize(to: .fixed(200))
            },
            makeButton("Resize to .percent(0.5)") { [weak self] in
                self?.sheetViewController?.resize(to: .percent(0.5))
            },
        ])
        buttons.axis = .vertical
        buttons.spacing = 12
        buttons.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttons)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: Self.headerHeight),
            header.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),

            headerLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),

            buttons.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 20),
            buttons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func makeButton(_ title: String, onTap: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .black
        button.setTitleColor(.white, for: .normal)
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.layer.cornerRadius = 22
        button.onTap(onTap)
        return button
    }

    static func openDemo(from parent: UIViewController, in view: UIView?) {
        let useInlineMode = view != nil

        var options = SheetOptions(useInlineMode: useInlineMode)
        if useInlineMode {
            var adaptive = AdaptiveInlineLayout()
            adaptive.regularWidthRule = .minimumContainerWidth(600)
            adaptive.regularWidthShadow = AdaptiveInlineLayout.Shadow(
                color: .black, opacity: 0.25, radius: 12, offset: CGSize(width: 0, height: 4))
            options.adaptiveInlineLayout = adaptive
        }

        // `.percent(0)` is a real detent here, so pulling the sheet down collapses it rather than
        // dismissing; the buttons exercise the programmatic path.
        let sheet = SheetViewController(
            controller: CollapseToZeroDemo(),
            sizes: [.fixed(200), .percent(0), .percent(0.5), .fullscreen],
            options: options)
        sheet.dismissOnPull = false

        addSheetEventLogging(to: sheet)

        guard let view = view else {
            parent.present(sheet, animated: true, completion: nil)
            return
        }

        // Collapsed content can't be tapped, so give the host a way back. This is the pattern an
        // app uses when it hides the sheet behind another overlay.
        let showButton = UIButton(type: .system)
        showButton.setTitle("Show sheet", for: .normal)
        showButton.backgroundColor = .systemGreen
        showButton.setTitleColor(.white, for: .normal)
        showButton.layer.cornerRadius = 22
        showButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        showButton.translatesAutoresizingMaskIntoConstraints = false
        showButton.isHidden = true
        showButton.onTap { [weak sheet] in
            sheet?.resize(to: .fixed(200))
        }

        let previousSizeChanged = sheet.sizeChanged
        sheet.sizeChanged = { sheet, size, height in
            showButton.isHidden = height > 0
            previousSizeChanged?(sheet, size, height)
        }
        let previousDidDismiss = sheet.didDismiss
        sheet.didDismiss = { sheet in
            showButton.removeFromSuperview()
            previousDidDismiss?(sheet)
        }

        sheet.animateIn(to: view, in: parent)

        view.addSubview(showButton)
        NSLayoutConstraint.activate([
            showButton.heightAnchor.constraint(equalToConstant: 44),
            showButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            showButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }
}
