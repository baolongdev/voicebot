import 'package:flutter/widgets.dart';

double iconScaleFactor(BuildContext context, {double min = 0.85, double max = 1.5}) {
  final scale = MediaQuery.textScaleFactorOf(context);
  if (scale < min) {
    return min;
  }
  if (scale > max) {
    return max;
  }
  return scale;
}

double scaledIconSize(BuildContext context, double base, {double min = 0.85, double max = 1.5}) {
  return base * iconScaleFactor(context, min: min, max: max);
}
