import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sizes the test surface like a phone instead of the 800x600 default.
///
/// The question screen skeleton (docs/26 §26.2) reserves a fixed 300dp stage
/// and anchors the response zone beneath the prompt. That comes to roughly
/// 650dp of content, which fits every real handset — the shortest phones this
/// app targets are around 844dp tall — but not the 600dp test default. Without
/// this, `Next` renders at y=840 and taps miss it.
///
/// Sizing the surface honestly is better than reaching for `ensureVisible` at
/// every tap: scrolling past the stage to reach a button is a workaround for a
/// viewport no child has, and it would hide a layout that genuinely did not
/// fit on a phone.
/// Call from `setUp` so it covers every test in the file.
void usePhoneViewport({Size size = const Size(420, 900)}) {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
  view.devicePixelRatio = 1.0;
  view.physicalSize = size;
}

/// Call from `tearDown`.
void resetPhoneViewport() {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
  view.resetPhysicalSize();
  view.resetDevicePixelRatio();
}
