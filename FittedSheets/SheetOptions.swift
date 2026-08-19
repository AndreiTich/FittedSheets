//
//  HandleOptions.swift
//  FittedSheetsPod
//
//  Created by Gordon Tucker on 7/29/20.
//  Copyright © 2020 Gordon Tucker. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

public struct SheetOptions {
    public static var `default` = SheetOptions()
    
    public enum TransitionOverflowType {
        case color(color: UIColor)
        case view(view: UIView)
        case none
        case automatic
    }
    
    public var pullBarHeight: CGFloat = 24
    
    public var presentingViewCornerRadius: CGFloat = 12
    public var shouldExtendBackground = true
    public var setIntrinsicHeightOnNavigationControllers = true

    public var transitionAnimationOptions: UIView.AnimationOptions = [.curveEaseOut]
    public var transitionDampening: CGFloat = 0.7
    public var transitionDuration: TimeInterval = 0.4
    /// Transition velocity base value. Automatically adjusts based on the initial size of the sheet.
    public var transitionVelocity: CGFloat = 0.8
    public var transitionOverflowType: TransitionOverflowType = .automatic
    
    /// When enabled, the sheet will snap to the closest sheet size relative to the calculated
    /// finalHeight in the panGesture, it will not take into account which direction the final
    /// point at which the gesture ends (which the default behavior does)
    public var shouldSnapToClosestSheetSize: Bool = false

    /// Default value 500, greater value will require more velocity to dismiss. Lesser values will do opposite.
    public var pullDismissThreshod: CGFloat = 500.0
    
    /// Allow the sheet to become full screen if pulled all the way to the top and not larger than the maximum size specified in sizes. Defaults to false.
    public var useFullScreenMode = true
    public var shrinkPresentingViewController = true
    /// Set true to be able to use the sheet view controller as a subview instead of a modal. Defaults to false.
    public var useInlineMode = false
    
    public var horizontalPadding: CGFloat = 0
    public var maxWidth: CGFloat?

    public var isRubberBandEnabled: Bool = false

    /// When set, `SheetViewController` pins its view to this layout guide instead of the
    /// parent view in `animateIn(to:in:size:)`. The guide must already be installed in the
    /// parent view's layout guide list before `animateIn` is called.
    ///
    /// Constraining the guide (rather than the sheet view directly) lets the host use the
    /// full Auto Layout toolkit — `safeAreaLayoutGuide` anchors, priority-based adaptive
    /// sizing, and pre-built activate/deactivate constraint sets — without the library
    /// needing to know any of those details. `nil` preserves the default full-parent
    /// edge-to-edge behavior.
    ///
    /// Ignored when ``adaptiveInlineLayout`` is set — the library owns the guide in that case.
    public var inlineLayoutGuide: UILayoutGuide? = nil

    /// When set, the sheet automatically switches between a full-width bottom card and a
    /// fixed-width leading panel as the container's size class or width changes. The library
    /// installs and updates its own layout guide — do not set ``inlineLayoutGuide`` manually.
    public var adaptiveInlineLayout: AdaptiveInlineLayout? = nil

    /// Experimental flag that attempts to shrink the nested presentations more each time a new sheet is presented. This must be set before any sheet is presented.
    public static var shrinkingNestedPresentingViewControllers = false
    
    public init() { }
    public init(pullBarHeight: CGFloat? = nil,
                presentingViewCornerRadius: CGFloat? = nil,
                shouldExtendBackground: Bool? = nil,
                setIntrinsicHeightOnNavigationControllers: Bool? = nil,
                useFullScreenMode: Bool? = nil,
                shrinkPresentingViewController: Bool? = nil,
                useInlineMode: Bool? = nil,
                horizontalPadding: CGFloat? = nil,
                maxWidth: CGFloat? = nil,
                isRubberBandEnabled: Bool? = nil,
                shouldSnapToClosestSheetSize: Bool? = nil) {
        let defaultOptions = SheetOptions.default
        self.pullBarHeight = pullBarHeight ?? defaultOptions.pullBarHeight
        self.presentingViewCornerRadius = presentingViewCornerRadius ?? defaultOptions.presentingViewCornerRadius
        self.shouldExtendBackground = shouldExtendBackground ?? defaultOptions.shouldExtendBackground
        self.setIntrinsicHeightOnNavigationControllers = setIntrinsicHeightOnNavigationControllers ?? defaultOptions.setIntrinsicHeightOnNavigationControllers
        self.useFullScreenMode = useFullScreenMode ?? defaultOptions.useFullScreenMode
        self.shrinkPresentingViewController = shrinkPresentingViewController ?? defaultOptions.shrinkPresentingViewController
        self.useInlineMode = useInlineMode ?? defaultOptions.useInlineMode
        self.horizontalPadding = horizontalPadding ?? defaultOptions.horizontalPadding
        let maxWidth = maxWidth ?? defaultOptions.maxWidth
        self.maxWidth = maxWidth == 0 ? nil : maxWidth
        self.isRubberBandEnabled = isRubberBandEnabled ?? false
        self.shouldSnapToClosestSheetSize = shouldSnapToClosestSheetSize ?? false
    }
    
    @available(*, unavailable, message: "cornerRadius, minimumSpaceAbovePullBar, gripSize and gripColor are now properties on SheetViewController. Use them instead.")
    public init(pullBarHeight: CGFloat? = nil,
                gripSize: CGSize? = nil,
                gripColor: UIColor? = nil,
                cornerRadius: CGFloat? = nil,
                presentingViewCornerRadius: CGFloat? = nil,
                shouldExtendBackground: Bool? = nil,
                setIntrinsicHeightOnNavigationControllers: Bool? = nil,
                useFullScreenMode: Bool? = nil,
                shrinkPresentingViewController: Bool? = nil,
                useInlineMode: Bool? = nil,
                minimumSpaceAbovePullBar: CGFloat? = nil) {
        let defaultOptions = SheetOptions.default
        self.pullBarHeight = pullBarHeight ?? defaultOptions.pullBarHeight
        self.presentingViewCornerRadius = presentingViewCornerRadius ?? defaultOptions.presentingViewCornerRadius
        self.shouldExtendBackground = shouldExtendBackground ?? defaultOptions.shouldExtendBackground
        self.setIntrinsicHeightOnNavigationControllers = setIntrinsicHeightOnNavigationControllers ?? defaultOptions.setIntrinsicHeightOnNavigationControllers
        self.useFullScreenMode = useFullScreenMode ?? defaultOptions.useFullScreenMode
        self.shrinkPresentingViewController = shrinkPresentingViewController ?? defaultOptions.shrinkPresentingViewController
        self.useInlineMode = useInlineMode ?? defaultOptions.useInlineMode
    }
}

#endif // os(iOS) || os(tvOS) || os(watchOS)
