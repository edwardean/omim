import UIKit

final class PhotosInteractionAnimator: NSObject {
  private enum Settings {
    static let returnToCenterVelocityAnimationRatio: CGFloat = 0.00007
    static let panDismissDistanceRatio: CGFloat = 0.075
    static let panDismissMaximumDuration: TimeInterval = 0.45
  }

  var animator: UIViewControllerAnimatedTransitioning?
  var viewToHideWhenBeginningTransition: UIView?
  var shouldAnimateUsingAnimator = false

  fileprivate var transitionContext: UIViewControllerContextTransitioning?

  func handlePanWithPanGestureRecognizer(_ gestureRecognizer: UIPanGestureRecognizer, viewToPan: UIView, anchorPoint: CGPoint) {
    guard let fromView = transitionContext?.view(forKey: UITransitionContextViewKey.from) else {
      return
    }
    let translatedPanGesturePoint = gestureRecognizer.translation(in: fromView)
    let newCenterPoint = CGPoint(x: anchorPoint.x, y: anchorPoint.y + translatedPanGesturePoint.y)

    viewToPan.center = newCenterPoint

    let verticalDelta = newCenterPoint.y - anchorPoint.y
    let backgroundAlpha = backgroundAlphaForPanningWithVerticalDelta(verticalDelta)
    fromView.backgroundColor = fromView.backgroundColor?.withAlphaComponent(backgroundAlpha)

    if gestureRecognizer.state == .ended, let transitionContext = transitionContext, let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from) {
      let velocityY = gestureRecognizer.velocity(in: gestureRecognizer.view).y
      finishPanWith(transitionContext: transitionContext, velocityY: velocityY, verticalDelta: verticalDelta, viewToPan: viewToPan, fromView: fromView, anchorPoint: anchorPoint)
    }
  }

  private func finishPanWith(transitionContext: UIViewControllerContextTransitioning, velocityY: CGFloat, verticalDelta: CGFloat, viewToPan: UIView, fromView: UIView, anchorPoint: CGPoint) {
    let dismissDistance = Settings.panDismissDistanceRatio * fromView.bounds.height
    let isDismissing = abs(verticalDelta) > dismissDistance

    if isDismissing, shouldAnimateUsingAnimator, let animator = animator {
      animator.animateTransition(using: transitionContext)
      self.transitionContext = nil
      return
    }

    let finalPageViewCenterPoint: CGPoint
    let animationDuration: TimeInterval
    let finalBackgroundAlpha: CGFloat

    if isDismissing {
      let modifier: CGFloat = verticalDelta.sign == .plus ? 1 : -1
      let finalCenterY = fromView.bounds.midY + modifier * fromView.bounds.height
      finalPageViewCenterPoint = CGPoint(x: fromView.center.x, y: finalCenterY)

      let duration = TimeInterval(abs(finalPageViewCenterPoint.y - viewToPan.center.y) / abs(velocityY))
      animationDuration = min(duration, Settings.panDismissMaximumDuration)
      finalBackgroundAlpha = 0.0
    } else {
      finalPageViewCenterPoint = anchorPoint
      animationDuration = TimeInterval(abs(velocityY) * Settings.returnToCenterVelocityAnimationRatio) + kDefaultAnimationDuration
      finalBackgroundAlpha = 1.0
    }
    let finalBackgroundColor = fromView.backgroundColor?.withAlphaComponent(finalBackgroundAlpha)
    finishPanWithoutAnimator(duration: animationDuration,
                             viewToPan: viewToPan, fromView: fromView,
                             finalPageViewCenterPoint: finalPageViewCenterPoint, finalBackgroundColor: finalBackgroundColor,
                             isDismissing: isDismissing)
  }

  private func finishPanWithoutAnimator(duration: TimeInterval, viewToPan: UIView, fromView: UIView, finalPageViewCenterPoint: CGPoint, finalBackgroundColor: UIColor?, isDismissing: Bool) {
    UIView.animate(withDuration: duration,
                   delay: 0,
                   options: .curveEaseOut,
                   animations: {
                    viewToPan.center = finalPageViewCenterPoint
                    fromView.backgroundColor = finalBackgroundColor
    },
                   completion: { [weak self] _ in
                    guard let s = self else { return }
                    if isDismissing {
                      s.transitionContext?.finishInteractiveTransition()
                    } else {
                      s.transitionContext?.cancelInteractiveTransition()
                      if !s.isRadar20070670Fixed() {
                        s.fixCancellationStatusBarAppearanceBug()
                      }
                    }
                    s.viewToHideWhenBeginningTransition?.alpha = 1.0
                    s.transitionContext?.completeTransition(isDismissing && !(s.transitionContext?.transitionWasCancelled ?? false))
                    s.transitionContext = nil
    })
  }

  private func fixCancellationStatusBarAppearanceBug() {
    guard let toViewController = self.transitionContext?.viewController(forKey: UITransitionContextViewControllerKey.to),
      let fromViewController = self.transitionContext?.viewController(forKey: UITransitionContextViewControllerKey.from) else {
        return
    }

    let statusBarViewControllerSelector = Selector("_setPresentedSta" + "tusBarViewController:")
    if toViewController.responds(to: statusBarViewControllerSelector) && fromViewController.modalPresentationCapturesStatusBarAppearance {
      toViewController.perform(statusBarViewControllerSelector, with: fromViewController)
    }
  }

  private func isRadar20070670Fixed() -> Bool {
    return ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion.init(majorVersion: 8, minorVersion: 3, patchVersion: 0))
  }

  private func backgroundAlphaForPanningWithVerticalDelta(_ delta: CGFloat) -> CGFloat {
    guard let fromView = transitionContext?.view(forKey: UITransitionContextViewKey.from) else {
      return 0.0
    }

    let startingAlpha: CGFloat = 1.0
    let finalAlpha: CGFloat = 0.1
    let totalAvailableAlpha = startingAlpha - finalAlpha

    let maximumDelta = CGFloat(fromView.bounds.height / 2.0)
    let deltaAsPercentageOfMaximum = min(abs(delta) / maximumDelta, 1.0)
    return startingAlpha - (deltaAsPercentageOfMaximum * totalAvailableAlpha)
  }
}

extension PhotosInteractionAnimator: UIViewControllerInteractiveTransitioning {
  func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
    viewToHideWhenBeginningTransition?.alpha = 0.0
    self.transitionContext = transitionContext
  }
}
