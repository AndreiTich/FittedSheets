//
//  AdaptiveInlineLayout.swift
//  FittedSheets
//
//  Automatic compact bottom-card ↔ regular-width leading-panel layout for inline sheets.
//

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

/// Configuration for an inline sheet that automatically switches between a full-width bottom
/// card (compact) and a fixed-width leading panel (regular width) as the container resizes.
public struct AdaptiveInlineLayout {
    /// How regular-width (leading panel) mode is chosen.
    public enum RegularWidthRule {
        /// ``UITraitCollection.horizontalSizeClass == .regular``
        case horizontalSizeClass
        /// Container width strictly greater than the given value (LeadingPanelDemo uses 600).
        case minimumContainerWidth(CGFloat)
        /// A host-defined rule for apps whose width-mode decision includes other state.
        case custom((UIView) -> Bool)
    }

    /// The horizontal edge that the regular-width panel is attached to.
    ///
    /// These values follow the interface's layout direction: `.leading` is left in a
    /// left-to-right interface and right in a right-to-left interface.
    public enum PanelEdge {
        case leading
        case trailing
    }

    /// The rectangle from which ``panelInsets`` are measured.
    public enum InsetReference {
        /// Measure insets from the container's safe-area edges.
        case safeArea
        /// Measure insets from the container's outer edges.
        case container
    }

    /// Drop-shadow configuration for the regular-width panel.
    public struct Shadow {
        public var color: UIColor?
        public var opacity: Float
        public var radius: CGFloat
        public var offset: CGSize

        public init(
            color: UIColor? = .black,
            opacity: Float,
            radius: CGFloat,
            offset: CGSize = .zero
        ) {
            self.color = color
            self.opacity = opacity
            self.radius = radius
            self.offset = offset
        }

        public static let none = Shadow(color: nil, opacity: 0, radius: 0)
        public static let subtle = Shadow(opacity: 0.12, radius: 8, offset: CGSize(width: 0, height: 2))
        public static let standard = Shadow(opacity: 0.2, radius: 16, offset: CGSize(width: 0, height: 4))
        public static let prominent = Shadow(opacity: 0.28, radius: 24, offset: CGSize(width: 0, height: 8))
    }

    public var regularWidthRule: RegularWidthRule = .minimumContainerWidth(600)
    public var panelWidth: CGFloat = 320
    public var panelEdge: PanelEdge = .leading
    /// Directional offsets from every edge of ``panelInsetReference``.
    ///
    /// The inset on ``panelEdge`` positions the panel. The opposite horizontal inset is
    /// enforced as a minimum margin, while `top` and `bottom` determine the panel's height.
    public var panelInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    public var panelInsetReference: InsetReference = .safeArea
    /// A regular-width-only corner radius. `nil` preserves the sheet's normal `cornerRadius`.
    public var regularWidthCornerRadius: CGFloat? = nil
    /// A regular-width-only shadow. Compact mode restores the sheet's previous shadow.
    public var regularWidthShadow: Shadow = .none
    public var hideGripInRegularWidth: Bool = true
    public var roundAllCornersInRegularWidth: Bool = true
    public var animateLayoutChanges: Bool = true

    public init() {}
}

/// Manages the layout guide and constraint swapping for ``SheetOptions.adaptiveInlineLayout``.
final class SheetAdaptiveInlineLayoutController {
    private weak var sheet: SheetViewController?
    private weak var parentView: UIView?
    private var config: AdaptiveInlineLayout

    private let layoutGuide = UILayoutGuide()
    private var compactConstraints: [NSLayoutConstraint] = []
    private var regularConstraints: [NSLayoutConstraint] = []
    private var sheetConstraints: [NSLayoutConstraint] = []
    private(set) var isRegularWidth = false
    private var didPerformInitialLayout = false
    private var originalVisualStyle: VisualStyle?

    private struct VisualStyle {
        let cornerRadius: CGFloat
        let wrapperMaskedCorners: CACornerMask
        let childMaskedCorners: CACornerMask
        let pullBarIsHidden: Bool
        let gripColor: UIColor?
        let shadowColor: CGColor?
        let shadowOpacity: Float
        let shadowRadius: CGFloat
        let shadowOffset: CGSize
        let shadowPath: CGPath?
        let overflowIsHidden: Bool
    }

    init(config: AdaptiveInlineLayout, sheet: SheetViewController) {
        self.config = config
        self.sheet = sheet
    }

    func install(in parentView: UIView) {
        self.parentView = parentView
        parentView.addLayoutGuide(layoutGuide)

        compactConstraints = [
            layoutGuide.topAnchor.constraint(equalTo: parentView.topAnchor),
            layoutGuide.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            layoutGuide.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            layoutGuide.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
        ]

        regularConstraints = makeRegularConstraints(in: parentView)

        isRegularWidth = shouldUseRegularWidth(in: parentView)
        sheet?.setAdaptiveRegularWidth(isRegularWidth)
        NSLayoutConstraint.activate(isRegularWidth ? regularConstraints : compactConstraints)

        guard let sheetView = sheet?.view else { return }
        captureOriginalVisualStyleIfNeeded()
        sheetView.translatesAutoresizingMaskIntoConstraints = false
        sheetConstraints = [
            sheetView.topAnchor.constraint(equalTo: layoutGuide.topAnchor),
            sheetView.bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor),
            sheetView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor),
            sheetView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor),
        ]
        NSLayoutConstraint.activate(sheetConstraints)
    }

    func updateLayoutIfNeeded(
        animated overrideAnimated: Bool? = nil,
        initialSize: SheetSize? = nil,
        forceUpdate: Bool = false
    ) {
        guard let parentView, let sheet else { return }

        let shouldRegular = shouldUseRegularWidth(in: parentView)
        let modeChanged = shouldRegular != isRegularWidth

        if modeChanged {
            NSLayoutConstraint.deactivate(isRegularWidth ? regularConstraints : compactConstraints)
            NSLayoutConstraint.activate(shouldRegular ? regularConstraints : compactConstraints)
            isRegularWidth = shouldRegular
            sheet.setAdaptiveRegularWidth(shouldRegular)
        }

        guard modeChanged || forceUpdate || !didPerformInitialLayout else {
            // Same mode, but the container may have resized (rotation, split view, window drag).
            // Keep the guide-defined fullscreen ceiling current and re-fit the sheet to it.
            trackContainerResize(sheet: sheet)
            return
        }
        didPerformInitialLayout = true

        applySizes(forRegularWidth: shouldRegular, sheet: sheet)
        let targetSize = initialSize ?? (forceUpdate ? sheet.currentSize : sheet.sizes.first) ?? sheet.currentSize
        // In regular mode the guide sits inside the safe area, so the sheet's post-transition
        // top inset is 0; in compact the sheet is full-bleed and inherits the parent's inset.
        // Passing the target-mode value keeps the prepared height identical to what
        // `height(for:)` computes after layout settles, so the corrective `resize` in
        // `finish` is a no-op instead of an end-of-animation snap.
        let targetBounds = targetGuideBounds(isRegularWidth: shouldRegular, in: parentView)
        // A regular-width panel has no pull bar, so its guide alone defines fullscreen.
        // Compensate for the drawer-only spacing before `height(for:)` subtracts it.
        sheet.adaptiveFullscreenHeight = shouldRegular
            ? targetBounds.height + sheet.minimumSpaceAbovePullBar
            : nil
        sheet.prepareResize(
            to: targetSize,
            withinBounds: targetBounds,
            safeAreaTop: shouldRegular
                ? 0
                : parentView.compatibleSafeAreaInsets.top - sheet.options.pullBarHeight)
        applyVisualStyle(isRegularWidth: shouldRegular, sheet: sheet)
        sheet.adaptiveLayoutDidChange?(sheet, shouldRegular)

        let finish = {
            guard sheet.view.superview != nil else { return }
            parentView.layoutIfNeeded()
            self.updateRegularShadowPathIfNeeded(sheet: sheet)
            if shouldRegular {
                sheet.resize(to: .fullscreen, animated: false)
            } else {
                // The host may select another compact detent while the mode-change animation is
                // running. Re-read it instead of replaying the target captured 0.4 seconds ago.
                sheet.resize(to: sheet.currentSize, animated: false)
            }
        }

        let animate = overrideAnimated
            ?? (config.animateLayoutChanges && (modeChanged || forceUpdate) && sheet.view.superview != nil)
        if animate {
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.3,
                options: .curveEaseInOut,
                animations: {
                    parentView.layoutIfNeeded()
                },
                completion: { _ in finish() }
            )
        } else {
            finish()
        }
    }

    func update(configuration: AdaptiveInlineLayout, animated: Bool) {
        guard let parentView else {
            config = configuration
            return
        }

        let wasRegularWidth = isRegularWidth
        if wasRegularWidth {
            NSLayoutConstraint.deactivate(regularConstraints)
        }
        config = configuration
        regularConstraints = makeRegularConstraints(in: parentView)
        if wasRegularWidth {
            NSLayoutConstraint.activate(regularConstraints)
        }

        let remainsRegularWidth = wasRegularWidth && shouldUseRegularWidth(in: parentView)
        updateLayoutIfNeeded(animated: animated, forceUpdate: remainsRegularWidth)
    }

    func tearDown() {
        if let sheet {
            restoreOriginalVisualStyle(sheet: sheet)
            sheet.adaptiveFullscreenHeight = nil
            sheet.setAdaptiveRegularWidth(false)
        }
        guard let parentView else { return }
        NSLayoutConstraint.deactivate(sheetConstraints + compactConstraints + regularConstraints)
        sheetConstraints = []
        parentView.removeLayoutGuide(layoutGuide)
    }

    /// Reconciles the fullscreen ceiling with the guide's settled geometry. Runs on every layout
    /// pass that isn't a mode change, so container resizes within a mode (e.g. iPad rotation
    /// while regular) re-fit the sheet instead of leaving a stale height.
    private func trackContainerResize(sheet: SheetViewController) {
        guard isRegularWidth else { return }
        updateRegularShadowPathIfNeeded(sheet: sheet)
        let guideHeight = layoutGuide.layoutFrame.height
        let fullscreenHeight = guideHeight + sheet.minimumSpaceAbovePullBar
        guard guideHeight > 0, sheet.adaptiveFullscreenHeight != fullscreenHeight else { return }
        sheet.adaptiveFullscreenHeight = fullscreenHeight
        sheet.resize(to: sheet.currentSize, animated: false)
    }

    private func shouldUseRegularWidth(in parentView: UIView) -> Bool {
        switch config.regularWidthRule {
        case .horizontalSizeClass:
            return parentView.traitCollection.horizontalSizeClass == .regular
        case .minimumContainerWidth(let width):
            return parentView.bounds.width > width
        case .custom(let rule):
            return rule(parentView)
        }
    }

    private func makeRegularConstraints(in parentView: UIView) -> [NSLayoutConstraint] {
        let referenceTop: NSLayoutYAxisAnchor
        let referenceBottom: NSLayoutYAxisAnchor
        let referenceLeading: NSLayoutXAxisAnchor
        let referenceTrailing: NSLayoutXAxisAnchor
        switch config.panelInsetReference {
        case .safeArea:
            referenceTop = parentView.safeAreaLayoutGuide.topAnchor
            referenceBottom = parentView.safeAreaLayoutGuide.bottomAnchor
            referenceLeading = parentView.safeAreaLayoutGuide.leadingAnchor
            referenceTrailing = parentView.safeAreaLayoutGuide.trailingAnchor
        case .container:
            referenceTop = parentView.topAnchor
            referenceBottom = parentView.bottomAnchor
            referenceLeading = parentView.leadingAnchor
            referenceTrailing = parentView.trailingAnchor
        }

        let insets = config.panelInsets
        let widthConstraint = layoutGuide.widthAnchor.constraint(equalToConstant: max(0, config.panelWidth))
        // Preserve the requested fixed width whenever it fits. If it does not, required edge
        // margins win and Auto Layout shrinks the panel instead of breaking constraints.
        widthConstraint.priority = UILayoutPriority(999)
        var constraints = [
            layoutGuide.topAnchor.constraint(equalTo: referenceTop, constant: insets.top),
            layoutGuide.bottomAnchor.constraint(equalTo: referenceBottom, constant: -insets.bottom),
            widthConstraint,
        ]
        switch config.panelEdge {
        case .leading:
            constraints.append(
                layoutGuide.leadingAnchor.constraint(equalTo: referenceLeading, constant: insets.leading))
            constraints.append(
                layoutGuide.trailingAnchor.constraint(lessThanOrEqualTo: referenceTrailing, constant: -insets.trailing))
        case .trailing:
            constraints.append(
                layoutGuide.trailingAnchor.constraint(equalTo: referenceTrailing, constant: -insets.trailing))
            constraints.append(
                layoutGuide.leadingAnchor.constraint(greaterThanOrEqualTo: referenceLeading, constant: insets.leading))
        }
        return constraints
    }

    private func targetGuideBounds(isRegularWidth: Bool, in parentView: UIView) -> CGRect {
        if isRegularWidth {
            let referenceFrame: CGRect
            switch config.panelInsetReference {
            case .safeArea:
                referenceFrame = parentView.safeAreaLayoutGuide.layoutFrame
            case .container:
                referenceFrame = parentView.bounds
            }
            return CGRect(
                x: 0,
                y: 0,
                width: min(
                    max(0, config.panelWidth),
                    max(0, referenceFrame.width - config.panelInsets.leading - config.panelInsets.trailing)),
                height: max(0, referenceFrame.height - config.panelInsets.top - config.panelInsets.bottom))
        } else {
            return CGRect(origin: .zero, size: parentView.bounds.size)
        }
    }

    private func applySizes(forRegularWidth isRegularWidth: Bool, sheet: SheetViewController) {
        let newSizes = isRegularWidth ? sheet.adaptiveRegularWidthSizes : sheet.adaptiveCompactSizes
        guard !newSizes.isEmpty else { return }
        sheet.sizes = newSizes
    }

    private func applyVisualStyle(isRegularWidth: Bool, sheet: SheetViewController) {
        captureOriginalVisualStyleIfNeeded()
        guard let originalVisualStyle else { return }

        let cv = sheet.contentViewController
        let allCorners: CACornerMask = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
        ]
        let topCornersOnly: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        if isRegularWidth {
            let mask = config.roundAllCornersInRegularWidth ? allCorners : topCornersOnly
            cv.contentWrapperView.layer.maskedCorners = mask
            cv.childContainerView.layer.maskedCorners = mask
            sheet.cornerRadius = config.regularWidthCornerRadius ?? originalVisualStyle.cornerRadius
        } else {
            cv.contentWrapperView.layer.maskedCorners = originalVisualStyle.wrapperMaskedCorners
            cv.childContainerView.layer.maskedCorners = originalVisualStyle.childMaskedCorners
            sheet.cornerRadius = originalVisualStyle.cornerRadius
        }

        if isRegularWidth && config.hideGripInRegularWidth {
            sheet.gripColor = .clear
            cv.pullBarView.isHidden = true
        } else {
            sheet.gripColor = originalVisualStyle.gripColor
            cv.pullBarView.isHidden = originalVisualStyle.pullBarIsHidden
        }

        let shadowLayer = cv.contentView.layer
        if isRegularWidth {
            let shadow = config.regularWidthShadow
            shadowLayer.shadowColor = shadow.color?.cgColor
            shadowLayer.shadowOpacity = shadow.opacity
            shadowLayer.shadowRadius = shadow.radius
            shadowLayer.shadowOffset = shadow.offset
            shadowLayer.shadowPath = nil
            cv.isOverflowViewHidden = true
        } else {
            restoreOriginalVisualStyle(sheet: sheet)
        }
    }

    private func captureOriginalVisualStyleIfNeeded() {
        guard originalVisualStyle == nil, let sheet else { return }
        let cv = sheet.contentViewController
        let shadowLayer = cv.contentView.layer
        originalVisualStyle = VisualStyle(
            cornerRadius: sheet.cornerRadius,
            wrapperMaskedCorners: cv.contentWrapperView.layer.maskedCorners,
            childMaskedCorners: cv.childContainerView.layer.maskedCorners,
            pullBarIsHidden: cv.pullBarView.isHidden,
            gripColor: sheet.gripColor,
            shadowColor: shadowLayer.shadowColor,
            shadowOpacity: shadowLayer.shadowOpacity,
            shadowRadius: shadowLayer.shadowRadius,
            shadowOffset: shadowLayer.shadowOffset,
            shadowPath: shadowLayer.shadowPath,
            overflowIsHidden: cv.isOverflowViewHidden)
    }

    private func restoreOriginalVisualStyle(sheet: SheetViewController) {
        guard let originalVisualStyle else { return }
        let cv = sheet.contentViewController
        cv.contentWrapperView.layer.maskedCorners = originalVisualStyle.wrapperMaskedCorners
        cv.childContainerView.layer.maskedCorners = originalVisualStyle.childMaskedCorners
        sheet.cornerRadius = originalVisualStyle.cornerRadius
        sheet.gripColor = originalVisualStyle.gripColor
        cv.pullBarView.isHidden = originalVisualStyle.pullBarIsHidden
        cv.isOverflowViewHidden = originalVisualStyle.overflowIsHidden

        let shadowLayer = cv.contentView.layer
        shadowLayer.shadowColor = originalVisualStyle.shadowColor
        shadowLayer.shadowOpacity = originalVisualStyle.shadowOpacity
        shadowLayer.shadowRadius = originalVisualStyle.shadowRadius
        shadowLayer.shadowOffset = originalVisualStyle.shadowOffset
        shadowLayer.shadowPath = originalVisualStyle.shadowPath
    }

    private func updateRegularShadowPathIfNeeded(sheet: SheetViewController) {
        guard isRegularWidth, config.regularWidthShadow.opacity > 0 else { return }
        let contentView = sheet.contentViewController.contentView
        let corners: UIRectCorner = config.roundAllCornersInRegularWidth
            ? [.topLeft, .topRight, .bottomLeft, .bottomRight]
            : [.topLeft, .topRight]
        let radius = config.regularWidthCornerRadius ?? originalVisualStyle?.cornerRadius ?? 0
        contentView.layer.shadowPath = UIBezierPath(
            roundedRect: contentView.bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath
    }
}

#endif
