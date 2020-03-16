// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart' show Drag, DragStartBehavior;
import 'package:flutter/foundation.dart' show precisionErrorTolerance;

class PrimaryPageController extends ScrollController {
  PrimaryPageController(
      {this.initialPage = 0,
      this.keepPage = true,
      this.viewportFraction = 1.0,
      this.coordinator,
      this.isInner = true})
      : assert(initialPage != null),
        assert(keepPage != null),
        assert(viewportFraction != null),
        assert(viewportFraction > 0.0);

  int initialPage;

  final bool keepPage;
  bool isInner;

  final double viewportFraction;

  PrimaryPageCoordinator coordinator;

  double get page {
    assert(
      positions.isNotEmpty,
      'PrimaryPageController.page cannot be accessed before a NestedPrimaryPageView is built with it.',
    );
    assert(
      positions.length == 1,
      'The page property cannot be read when multiple PageViews are attached to '
      'the same PrimaryPageController.',
    );
    final PrimaryPagePosition position = this.position;
    return position.page;
  }

  Future<void> animateToPage(
    int page, {
    @required Duration duration,
    @required Curve curve,
  }) {
    final PrimaryPagePosition position = this.position;
    return position.animateTo(
      position.getPixelsFromPage(page.toDouble()),
      duration: duration,
      curve: curve,
    );
  }

  void jumpToPage(int page) {
    final PrimaryPagePosition position = this.position;
    position.jumpTo(position.getPixelsFromPage(page.toDouble()));
  }

  Future<void> nextPage({@required Duration duration, @required Curve curve}) {
    return animateToPage(page.round() + 1, duration: duration, curve: curve);
  }

  Future<void> previousPage(
      {@required Duration duration, @required Curve curve}) {
    return animateToPage(page.round() - 1, duration: duration, curve: curve);
  }

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics,
      ScrollContext context, ScrollPosition oldPosition) {
    return PrimaryPagePosition(
        physics: physics,
        context: context,
        initialPage: initialPage,
        keepPage: keepPage,
        viewportFraction: viewportFraction,
        coordinator: coordinator,
        oldPosition: oldPosition,
        isInner: isInner);
  }

  @override
  void attach(ScrollPosition position) {

    super.attach(position);
    final PrimaryPagePosition pagePosition = position;
    pagePosition.viewportFraction = viewportFraction;

    if (position is PrimaryPagePosition) {
      position.coordinator = coordinator;
    }
  }

  @override
  void detach(ScrollPosition position) {

    if (positions.contains(position)) {
      super.detach(position);
    }
  }
}

//class PageMetrics extends FixedScrollMetrics {
//  /// Creates an immutable snapshot of values associated with a [PrimaryPageView].
//  PageMetrics({
//    @required double minScrollExtent,
//    @required double maxScrollExtent,
//    @required double pixels,
//    @required double viewportDimension,
//    @required AxisDirection axisDirection,
//    @required this.viewportFraction,
//  }) : super(
//          minScrollExtent: minScrollExtent,
//          maxScrollExtent: maxScrollExtent,
//          pixels: pixels,
//          viewportDimension: viewportDimension,
//          axisDirection: axisDirection,
//        );
//
//  @override
//  PageMetrics copyWith({
//    double minScrollExtent,
//    double maxScrollExtent,
//    double pixels,
//    double viewportDimension,
//    AxisDirection axisDirection,
//    double viewportFraction,
//  }) {
//    return PageMetrics(
//      minScrollExtent: minScrollExtent ?? this.minScrollExtent,
//      maxScrollExtent: maxScrollExtent ?? this.maxScrollExtent,
//      pixels: pixels ?? this.pixels,
//      viewportDimension: viewportDimension ?? this.viewportDimension,
//      axisDirection: axisDirection ?? this.axisDirection,
//      viewportFraction: viewportFraction ?? this.viewportFraction,
//    );
//  }
//
//  /// The current page displayed in the [PrimaryPageView].
//  double get page {
//    return math.max(0.0, pixels.clamp(minScrollExtent, maxScrollExtent)) /
//        math.max(1.0, viewportDimension * viewportFraction);
//  }
//
//  /// The fraction of the viewport that each page occupies.
//  ///
//  /// Used to compute [page] from the current [pixels].
//  final double viewportFraction;
//}

class PrimaryPagePosition extends ScrollPosition
    implements PageMetrics, ScrollActivityDelegate {
  PrimaryPagePosition(
      {ScrollPhysics physics,
      ScrollContext context,
      this.initialPage = 0,
      bool keepPage = true,
      double viewportFraction = 1.0,
      double initialPixels = 0.0,
      ScrollPosition oldPosition,
      this.coordinator,
      this.isInner = true})
      : assert(initialPage != null),
        assert(keepPage != null),
        assert(viewportFraction != null),
        assert(viewportFraction > 0.0),
        _viewportFraction = viewportFraction,
        _pageToUseOnStartup = initialPage.toDouble(),
        super(
          physics: physics,
          context: context,
          keepScrollOffset: keepPage,
          oldPosition: oldPosition,
        ) {
    if (activity == null) goIdle();
    assert(activity != null);
  }

  final int initialPage;
  PrimaryPageCoordinator coordinator;
  final bool isInner;
  double _pageToUseOnStartup;

  @override
  double get viewportFraction => _viewportFraction;
  double _viewportFraction;

  set viewportFraction(double value) {
    if (_viewportFraction == value) return;
    final double oldPage = page;
    _viewportFraction = value;
    if (oldPage != null) forcePixels(getPixelsFromPage(oldPage));
  }

  // The amount of offset that will be added to [minScrollExtent] and subtracted
  // from [maxScrollExtent], such that every page will properly snap to the center
  // of the viewport when viewportFraction is greater than 1.
  //
  // The value is 0 if viewportFraction is less than or equal to 1, larger than 0
  // otherwise.
  double get _initialPageOffset =>
      math.max(0, viewportDimension * (viewportFraction - 1) / 2);

  double getPageFromPixels(double pixels, double viewportDimension) {
    final double actual = math.max(0.0, pixels - _initialPageOffset) /
        math.max(1.0, viewportDimension * viewportFraction);
    final double round = actual.roundToDouble();
    if ((actual - round).abs() < precisionErrorTolerance) {
      return round;
    }
    return actual;
  }

  double getPixelsFromPage(double page) {
    return page * viewportDimension * viewportFraction + _initialPageOffset;
  }

  @override
  double get page {
    assert(
      pixels == null || (minScrollExtent != null && maxScrollExtent != null),
      'Page value is only available after content dimensions are established.',
    );
    return pixels == null
        ? null
        : getPageFromPixels(
            pixels.clamp(minScrollExtent, maxScrollExtent), viewportDimension);
  }

  @override
  void saveScrollOffset() {
    PageStorage.of(context.storageContext)?.writeState(
        context.storageContext, getPageFromPixels(pixels, viewportDimension));
  }

  @override
  void restoreScrollOffset() {
    if (pixels == null) {
      final double value = PageStorage.of(context.storageContext)
          ?.readState(context.storageContext);
      if (value != null) _pageToUseOnStartup = value;
    }
  }

  @override
  bool applyViewportDimension(double viewportDimension) {
    final double oldViewportDimensions = this.viewportDimension;
    final bool result = super.applyViewportDimension(viewportDimension);
    final double oldPixels = pixels;
    final double page = (oldPixels == null || oldViewportDimensions == 0.0)
        ? _pageToUseOnStartup
        : getPageFromPixels(oldPixels, this.viewportDimension);
    final double newPixels = getPixelsFromPage(page);

    if (newPixels != oldPixels) {
      correctPixels(newPixels);
      return false;
    }
    return result;
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final double newMinScrollExtent = minScrollExtent + _initialPageOffset;
    return super.applyContentDimensions(
      newMinScrollExtent,
      math.max(newMinScrollExtent, maxScrollExtent - _initialPageOffset),
    );
  }

  @override
  PageMetrics copyWith({
    double minScrollExtent,
    double maxScrollExtent,
    double pixels,
    double viewportDimension,
    AxisDirection axisDirection,
    double viewportFraction,
  }) {
    return PageMetrics(
      minScrollExtent: minScrollExtent ?? this.minScrollExtent,
      maxScrollExtent: maxScrollExtent ?? this.maxScrollExtent,
      pixels: pixels ?? this.pixels,
      viewportDimension: viewportDimension ?? this.viewportDimension,
      axisDirection: axisDirection ?? this.axisDirection,
      viewportFraction: viewportFraction ?? this.viewportFraction,
    );
  }

  /// Velocity from a previous activity temporarily held by [hold] to potentially
  /// transfer to a next activity.
  double _heldPreviousVelocity = 0.0;

  @override
  AxisDirection get axisDirection => context.axisDirection;

  @override
  double setPixels(double newPixels) {
    assert(activity.isScrolling);
    return super.setPixels(newPixels);
  }

  @override
  void absorb(ScrollPosition other) {
    super.absorb(other);
    if (other is! ScrollPositionWithSingleContext) {
      goIdle();
      return;
    }
    activity.updateDelegate(this);
    final PrimaryPagePosition typedOther = other;
    _userScrollDirection = typedOther._userScrollDirection;
    assert(_currentDrag == null);
    if (typedOther._currentDrag != null) {
      _currentDrag = typedOther._currentDrag;
      _currentDrag.updateDelegate(this);
      typedOther._currentDrag = null;
    }
  }

  @override
  void applyNewDimensions() {
    super.applyNewDimensions();
    context.setCanDrag(physics.shouldAcceptUserOffset(this));
  }

  @override
  void beginActivity(ScrollActivity newActivity) {
    _heldPreviousVelocity = 0.0;
    if (newActivity == null) return;
    super.beginActivity(newActivity);
    _currentDrag?.dispose();
    _currentDrag = null;
    if (!activity.isScrolling) updateUserScrollDirection(ScrollDirection.idle);
  }

  @override
  void applyUserOffset(double delta) {
    updateUserScrollDirection(
        delta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse);
    setPixels(pixels - physics.applyPhysicsToUserOffset(this, delta));
  }

  @override
  void goIdle() {
    beginActivity(IdleScrollActivity(this));
  }

  /// Start a physics-driven simulation that settles the [pixels] position,
  /// starting at a particular velocity.
  ///
  /// This method defers to [ScrollPhysics.createBallisticSimulation], which
  /// typically provides a bounce simulation when the current position is out of
  /// bounds and a friction simulation when the position is in bounds but has a
  /// non-zero velocity.
  ///
  /// The velocity should be in logical pixels per second.
  @override
  void goBallistic(double velocity) {
    assert(pixels != null);
    final Simulation simulation =
        physics.createBallisticSimulation(this, velocity);
    if (simulation != null) {
      beginActivity(BallisticScrollActivity(this, simulation, context.vsync));
    } else {
      goIdle();
    }
  }

  @override
  ScrollDirection get userScrollDirection => _userScrollDirection;
  ScrollDirection _userScrollDirection = ScrollDirection.idle;

  /// Set [userScrollDirection] to the given value.
  ///
  /// If this changes the value, then a [UserScrollNotification] is dispatched.
  @protected
  @visibleForTesting
  void updateUserScrollDirection(ScrollDirection value) {
    assert(value != null);
    if (userScrollDirection == value) return;
    _userScrollDirection = value;
    didUpdateScrollDirection(value);
  }

  @override
  Future<void> animateTo(
    double to, {
    @required Duration duration,
    @required Curve curve,
  }) {
    if (nearEqual(to, pixels, physics.tolerance.distance)) {
      // Skip the animation, go straight to the position as we are already close.
      jumpTo(to);
      return Future<void>.value();
    }

    final DrivenScrollActivity activity = DrivenScrollActivity(
      this,
      from: pixels,
      to: to,
      duration: duration,
      curve: curve,
      vsync: context.vsync,
    );
    beginActivity(activity);
    return activity.done;
  }

  @override
  void jumpTo(double value) {
    goIdle();
    if (pixels != value) {
      final double oldPixels = pixels;
      forcePixels(value);
      notifyListeners();
      didStartScroll();
      didUpdateScrollPositionBy(pixels - oldPixels);
      didEndScroll();
    }
    goBallistic(0.0);
  }

  @Deprecated(
      'This will lead to bugs.') // ignore: flutter_deprecation_syntax, https://github.com/flutter/flutter/issues/44609
  @override
  void jumpToWithoutSettling(double value) {
    goIdle();
    if (pixels != value) {
      final double oldPixels = pixels;
      forcePixels(value);
      notifyListeners();
      didStartScroll();
      didUpdateScrollPositionBy(pixels - oldPixels);
      didEndScroll();
    }
  }

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    if (coordinator != null && coordinator.isOuterControllerEnable()) {
      return coordinator.hold(holdCancelCallback);
    } else {
      final double previousVelocity = activity.velocity;
      final HoldScrollActivity holdActivity = HoldScrollActivity(
        delegate: this,
        onHoldCanceled: holdCancelCallback,
      );
      beginActivity(holdActivity);
      _heldPreviousVelocity = previousVelocity;
      return holdActivity;
    }
  }

  ScrollDragController _currentDrag;

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    if (coordinator != null && coordinator.isOuterControllerEnable()) {
      return coordinator.drag(details, dragCancelCallback, isInner);
    } else {
      final ScrollDragController drag = ScrollDragController(
        delegate: this,
        details: details,
        onDragCanceled: dragCancelCallback,
        carriedVelocity: physics.carriedMomentum(_heldPreviousVelocity),
        motionStartDistanceThreshold: physics.dragStartDistanceMotionThreshold,
      );
      beginActivity(DragScrollActivity(this, drag));
      assert(_currentDrag == null);
      _currentDrag = drag;
      return drag;
    }
  }

  @override
  void dispose() {
    _currentDrag?.dispose();
    _currentDrag = null;
    super.dispose();
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('${context.runtimeType}');
    description.add('$physics');
    description.add('$activity');
    description.add('$userScrollDirection');
  }

  // Returns the amount of delta that was not used.
  //
  // Positive delta means going down (exposing stuff above), negative delta
  // going up (exposing stuff below).
  double applyClampedDragUpdate(double delta) {
    assert(delta != 0.0);
    // If we are going towards the maxScrollExtent (negative scroll offset),
    // then the furthest we can be in the minScrollExtent direction is negative
    // infinity. For example, if we are already overscrolled, then scrolling to
    // reduce the overscroll should not disallow the overscroll.
    //
    // If we are going towards the minScrollExtent (positive scroll offset),
    // then the furthest we can be in the minScrollExtent direction is wherever
    // we are now, if we are already overscrolled (in which case pixels is less
    // than the minScrollExtent), or the minScrollExtent if we are not.
    //
    // In other words, we cannot, via applyClampedDragUpdate, _enter_ an
    // overscroll situation.
    //
    // An overscroll situation might be nonetheless entered via several means.
    // One is if the physics allow it, via applyFullDragUpdate (see below). An
    // overscroll situation can also be forced, e.g. if the scroll position is
    // artificially set using the scroll controller.
    final double min =
        delta < 0.0 ? -double.infinity : math.min(minScrollExtent, pixels);
    // The logic for max is equivalent but on the other side.
    final double max =
        delta > 0.0 ? double.infinity : math.max(maxScrollExtent, pixels);
    final double oldPixels = pixels;
    final double newPixels = (pixels - delta).clamp(min, max);
    final double clampedDelta = newPixels - pixels;
    if (clampedDelta == 0.0) return delta;
    final double overscroll = physics.applyBoundaryConditions(this, newPixels);
    final double actualNewPixels = newPixels - overscroll;
    final double offset = actualNewPixels - oldPixels;
    if (offset != 0.0) {
      forcePixels(actualNewPixels);
      didUpdateScrollPositionBy(offset);
    }
    return delta + offset;
  }

  // Returns the overscroll.
  double applyFullDragUpdate(double delta) {
    assert(delta != 0.0);
    final double oldPixels = pixels;
    // Apply friction:
    final double newPixels =
        pixels - physics.applyPhysicsToUserOffset(this, delta);
    if (oldPixels == newPixels)
      return 0.0; // delta must have been so small we dropped it during floating point addition
    // Check for overscroll:
    final double overscroll = physics.applyBoundaryConditions(this, newPixels);
    final double actualNewPixels = newPixels - overscroll;
    if (actualNewPixels != oldPixels) {
      forcePixels(actualNewPixels);
      didUpdateScrollPositionBy(actualNewPixels - oldPixels);
    }
    if (overscroll != 0.0) {
      didOverscrollBy(overscroll);
      return overscroll;
    }
    return 0.0;
  }
}

class PrimaryPageCoordinator
    implements ScrollActivityDelegate, ScrollHoldController {
  PrimaryPageController _outerController;
  PrimaryPageController _selfController;

  ScrollDragController _currentDrag;

  bool isOperateBody = false;

  PrimaryPageCoordinator(PrimaryPageController selfController,
      PrimaryPageController parentController) {
    _selfController = selfController;
    _selfController.coordinator = this;

    _outerController = parentController;
    _outerController.coordinator = this;
  }

  PrimaryPageController getOuterController() {
    return _outerController;
  }

  bool isOuterControllerEnable() {
    return _outerController != null && _outerController.hasClients;
  }

  PrimaryPageController getInnerController() {
    return _selfController;
  }

  bool isInnerControllerEnable() {
    return _selfController != null && _selfController.hasClients;
  }

  @override
  void applyUserOffset(double delta) {
    updateUserScrollDirection(
        delta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse);

    PrimaryPagePosition innerPosition =
        (getInnerController().position as PrimaryPagePosition);
    PrimaryPagePosition outPosition = isOuterControllerEnable()
        ? (getOuterController().position as PrimaryPagePosition)
        : null;

    if (isOperateBody) {
      if ((outPosition?.pixels == outPosition?.minScrollExtent ||
              outPosition?.pixels == outPosition?.maxScrollExtent) &&
          (delta < 0
              ? innerPosition.pixels < innerPosition.maxScrollExtent
              : innerPosition.pixels > innerPosition.minScrollExtent)) {
        innerPosition.applyUserOffset(delta);
      } else {
        outPosition.applyUserOffset(delta);
      }
    } else {
      outPosition.applyUserOffset(delta);
    }
  }

  @override
  AxisDirection get axisDirection => _outerController.position.axisDirection;

  @override
  void cancel() {
    goBallistic(0.0);
  }

  @override
  void goBallistic(double velocity) {
    PrimaryPagePosition innerPosition =
        (getInnerController().position as PrimaryPagePosition);
    PrimaryPagePosition outPosition = isOuterControllerEnable()
        ? (getOuterController().position as PrimaryPagePosition)
        : null;

    if (isOperateBody) {
      if ((outPosition != null) &&
          (outPosition.pixels > outPosition.minScrollExtent &&
              outPosition.pixels < outPosition.maxScrollExtent)) {
        outPosition.goBallistic(velocity);
        innerPosition.goIdle();

        _currentDrag?.dispose();
        _currentDrag = null;

        return;
      }

      if (velocity > 0) {
        if (innerPosition.pixels < innerPosition.maxScrollExtent &&
            innerPosition.pixels > innerPosition.minScrollExtent) {
          innerPosition.goBallistic(velocity);
          outPosition?.goIdle();
        } else {
          outPosition?.goBallistic(velocity);
          innerPosition.goIdle();
        }
      } else {
        if (innerPosition.pixels < innerPosition.maxScrollExtent) {
          innerPosition.goBallistic(velocity);
          outPosition?.goIdle();
        } else {
          outPosition?.goBallistic(velocity);
          innerPosition.goIdle();
        }
      }
    } else {
      outPosition?.goBallistic(velocity);
      innerPosition.goIdle();
    }

    _currentDrag?.dispose();
    _currentDrag = null;
  }

  @override
  void goIdle() {
    beginActivity(IdleScrollActivity(this), IdleScrollActivity(this));
  }

  @override
  double setPixels(double pixels) {
    return 0.0;
  }

  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    beginActivity(
        HoldScrollActivity(delegate: this, onHoldCanceled: holdCancelCallback),
        HoldScrollActivity(delegate: this, onHoldCanceled: holdCancelCallback));

    return this;
  }

  Drag drag(
      DragStartDetails details, VoidCallback dragCancelCallback, bool isInner) {
    isOperateBody = isInner;

    final ScrollDragController drag = ScrollDragController(
      delegate: this,
      details: details,
      onDragCanceled: dragCancelCallback,
    );

    beginActivity(
        DragScrollActivity(this, drag), DragScrollActivity(this, drag));

    assert(_currentDrag == null);
    _currentDrag = drag;
    return drag;
  }

  void beginActivity(
      ScrollActivity newOuterActivity, ScrollActivity newInnerActivity) {
    getInnerController().position.beginActivity(newInnerActivity);
    if (isOuterControllerEnable()) {
      getOuterController().position.beginActivity(newOuterActivity);
    }

    _currentDrag?.dispose();
    _currentDrag = null;

    if ((newOuterActivity == null || !newOuterActivity.isScrolling) &&
        (newInnerActivity == null || !newInnerActivity.isScrolling)) {
      updateUserScrollDirection(ScrollDirection.idle);
    }
  }

  ScrollDirection get userScrollDirection => _userScrollDirection;
  ScrollDirection _userScrollDirection = ScrollDirection.idle;

  void updateUserScrollDirection(ScrollDirection value) {
    assert(value != null);
    if (userScrollDirection == value) return;
    _userScrollDirection = value;
    getOuterController().position.didUpdateScrollDirection(value);
    if (isOuterControllerEnable()) {
      getInnerController().position.didUpdateScrollDirection(value);
    }
  }
}

class PageScrollPhysics extends ScrollPhysics {
  /// Creates physics for a [PrimaryPageView].
  const PageScrollPhysics({ScrollPhysics parent}) : super(parent: parent);

  @override
  PageScrollPhysics applyTo(ScrollPhysics ancestor) {
    return PageScrollPhysics(parent: buildParent(ancestor));
  }

  double _getPage(ScrollMetrics position) {
    if (position is PrimaryPagePosition) return position.page;
    return position.pixels / position.viewportDimension;
  }

  double _getPixels(ScrollMetrics position, double page) {
    if (position is PrimaryPagePosition)
      return position.getPixelsFromPage(page);
    return page * position.viewportDimension;
  }

  double _getTargetPixels(
      ScrollMetrics position, Tolerance tolerance, double velocity) {
    double page = _getPage(position);
    if (velocity < -tolerance.velocity)
      page -= 0.5;
    else if (velocity > tolerance.velocity) page += 0.5;
    return _getPixels(position, page.roundToDouble());
  }

  @override
  Simulation createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // If we're out of range and not headed back in range, defer to the parent
    // ballistics, which should put us back in range at a page boundary.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent))
      return super.createBallisticSimulation(position, velocity);
    final Tolerance tolerance = this.tolerance;
    final double target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels)
      return ScrollSpringSimulation(spring, position.pixels, target, velocity,
          tolerance: tolerance);
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}

const PageScrollPhysics _kPagePhysics = PageScrollPhysics();

class PrimaryPageView extends StatefulWidget {
  /// Creates a scrollable list that works page by page from an explicit [List]
  /// of widgets.
  ///
  /// This constructor is appropriate for page views with a small number of
  /// children because constructing the [List] requires doing work for every
  /// child that could possibly be displayed in the page view, instead of just
  /// those children that are actually visible.
  PrimaryPageView({
    Key key,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.controller,
    this.physics,
    this.pageSnapping = true,
    this.onPageChanged,
    this.primary = false,
    List<Widget> children = const <Widget>[],
    this.dragStartBehavior = DragStartBehavior.start,
  })  : childrenDelegate = SliverChildListDelegate(children),
        super(key: key) {
    if (this.controller == null) {
      this.controller = PrimaryPageController();
      this.controller.isInner = primary;
    }
  }

  /// Creates a scrollable list that works page by page using widgets that are
  /// created on demand.
  ///delta
  /// This constructor is appropriate for page views with a large (or infinite)
  /// number of children because the builder is called only for those children
  /// that are actually visible.
  ///
  /// Providing a non-null [itemCount] lets the [PrimaryPageView] compute the maximum
  /// scroll extent.
  ///
  /// [itemBuilder] will be called only with indices greater than or equal to
  /// zero and less than [itemCount].
  ///
  /// [PrimaryPageView.builder] by default does not support child reordering. If
  /// you are planning to change child order at a later time, consider using
  /// [PrimaryPageView] or [PrimaryPageView.custom].
  PrimaryPageView.builder({
    Key key,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.controller,
    this.physics,
    this.pageSnapping = true,
    this.onPageChanged,
    @required IndexedWidgetBuilder itemBuilder,
    int itemCount,
    this.primary = false,
    this.dragStartBehavior = DragStartBehavior.start,
  })  : childrenDelegate =
            SliverChildBuilderDelegate(itemBuilder, childCount: itemCount),
        super(key: key) {
    if (this.controller == null) {
      this.controller = PrimaryPageController();
      this.controller.isInner = primary;
    }
  }

  PrimaryPageView.custom({
    Key key,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.controller,
    this.physics,
    this.pageSnapping = true,
    this.onPageChanged,
    @required this.childrenDelegate,
    this.primary = false,
    this.dragStartBehavior = DragStartBehavior.start,
  })  : assert(childrenDelegate != null),
        super(key: key) {
    if (this.controller == null) {
      this.controller = PrimaryPageController();
      this.controller.isInner = primary;
    }
  }

  /// The axis along which the page view scrolls.
  ///
  /// Defaults to [Axis.horizontal].
  final Axis scrollDirection;

  /// Whether the page view scrolls in the reading direction.
  ///
  /// For example, if the reading direction is left-to-right and
  /// [scrollDirection] is [Axis.horizontal], then the page view scrolls from
  /// left to right when [reverse] is false and from right to left when
  /// [reverse] is true.
  ///
  /// Similarly, if [scrollDirection] is [Axis.vertical], then the page view
  /// scrolls from top to bottom when [reverse] is false and from bottom to top
  /// when [reverse] is true.
  ///
  /// Defaults to false.
  final bool reverse;

  /// An object that can be used to control the position to which this page
  /// view is scrolled.
  PrimaryPageController controller;

  /// How the page view should respond to user input.
  ///
  /// For example, determines how the page view continues to animate after the
  /// user stops dragging the page view.
  ///
  /// The physics are modified to snap to page boundaries using
  /// [PageScrollPhysics] prior to being used.
  ///
  /// Defaults to matching platform conventions.
  final ScrollPhysics physics;

  /// Set to false to disable page snapping, useful for custom scroll behavior.
  final bool pageSnapping;

  /// Called whenever the page in the center of the viewport changes.
  final ValueChanged<int> onPageChanged;

  /// A delegate that provides the children for the [PrimaryPageView].
  ///
  /// The [PrimaryPageView.custom] constructor lets you specify this delegate
  /// explicitly. The [PrimaryPageView] and [PrimaryPageView.builder] constructors create a
  /// [childrenDelegate] that wraps the given [List] and [IndexedWidgetBuilder],
  /// respectively.
  final SliverChildDelegate childrenDelegate;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  final bool primary;

  @override
  _PageViewState createState() => _PageViewState();
}

class _PageViewState extends State<PrimaryPageView> {
  int _lastReportedPage = 0;
  PrimaryPageCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _lastReportedPage = widget.controller.initialPage;
  }

  AxisDirection _getDirection(BuildContext context) {
    switch (widget.scrollDirection) {
      case Axis.horizontal:
        assert(debugCheckHasDirectionality(context));
        final TextDirection textDirection = Directionality.of(context);
        final AxisDirection axisDirection =
            textDirectionToAxisDirection(textDirection);
        return widget.reverse
            ? flipAxisDirection(axisDirection)
            : axisDirection;
      case Axis.vertical:
        return widget.reverse ? AxisDirection.up : AxisDirection.down;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AxisDirection axisDirection = _getDirection(context);
    final ScrollPhysics physics = widget.pageSnapping
        ? _kPagePhysics.applyTo(widget.physics)
        : widget.physics;

    final ScrollController scrollController = widget.primary
        ? PrimaryScrollController.of(context)
        : widget.controller;

    if (widget.primary && scrollController is PrimaryPageController) {
      scrollController.initialPage = _lastReportedPage;
      _coordinator =
          PrimaryPageCoordinator(widget.controller, scrollController);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification.depth == 0 &&
            widget.onPageChanged != null &&
            notification is ScrollUpdateNotification) {
          final PageMetrics metrics = notification.metrics;
          final int currentPage = metrics.page.round();
          if (currentPage != _lastReportedPage) {
            _lastReportedPage = currentPage;
            widget.onPageChanged(currentPage);
          }
        }
        return false;
      },
      child: Scrollable(
        dragStartBehavior: widget.dragStartBehavior,
        axisDirection: axisDirection,
        controller: widget.controller,
        physics: physics,
        viewportBuilder: (BuildContext context, ViewportOffset position) {
          return Viewport(
            cacheExtent: 0.0,
            axisDirection: axisDirection,
            offset: position,
            slivers: <Widget>[
              PrimaryScrollController(
                  controller: widget.controller,
                  child: SliverFillViewport(
                    viewportFraction: widget.controller.viewportFraction,
                    delegate: widget.childrenDelegate,
                  )),
            ],
          );
        },
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description
        .add(EnumProperty<Axis>('scrollDirection', widget.scrollDirection));
    description.add(
        FlagProperty('reverse', value: widget.reverse, ifTrue: 'reversed'));
    description.add(DiagnosticsProperty<PrimaryPageController>(
        'controller', widget.controller,
        showName: false));
    description.add(DiagnosticsProperty<ScrollPhysics>(
        'physics', widget.physics,
        showName: false));
    description.add(FlagProperty('pageSnapping',
        value: widget.pageSnapping, ifFalse: 'snapping disabled'));
  }
}
