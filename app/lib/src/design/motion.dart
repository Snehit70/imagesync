import 'package:flutter/animation.dart';

abstract final class Motion {
  /// Widget tests set this to false so looping animations (blob morph,
  /// pulsing dots, ripple rings) don't keep pumpAndSettle from terminating.
  static bool loopsEnabled = true;

  static const spring = Cubic(0.34, 1.56, 0.64, 1);
  static const entrance = Duration(milliseconds: 600);
  static const stagger = Duration(milliseconds: 100);
  static const pressDown = Duration(milliseconds: 120);
  static const pressUp = Duration(milliseconds: 300);
}
