//
//  SnapToClosestSheetSizeDemo.swift
//  Demos
//
//  Created by Andrei Tich on 1/30/25.
//  MIT License
//

import UIKit
import FittedSheets

class SnapToClosestSheetSizeDemo: SimpleDemo {
    override class var name: String { "Snap to closest sheet size" }

    override class func openDemo(from parent: UIViewController, in view: UIView?) {
        let useInlineMode = view != nil

        let controller = ColorDemo()
        let options = SheetOptions(
            useInlineMode: useInlineMode,
            shouldSnapToClosestSheetSize: true)


        let sheet = SheetViewController(
            controller: controller,
            sizes: [.percent(0.3), .percent(0.60), .fullscreen],
            options: options)
        sheet.allowPullingPastMaxHeight = false
        sheet.allowPullingPastMinHeight = false

        addSheetEventLogging(to: sheet)

        if let view = view {
            sheet.animateIn(to: view, in: parent)
        } else {
            parent.present(sheet, animated: true, completion: nil)
        }
    }
}
