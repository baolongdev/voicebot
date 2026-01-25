import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

typedef ResponsiveWidgetBuilder = Widget Function(BuildContext context);

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final ResponsiveWidgetBuilder mobile;
  final ResponsiveWidgetBuilder? tablet;
  final ResponsiveWidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    final breakpoints = context.theme.breakpoints;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (desktop != null && width >= breakpoints.lg) {
          return desktop!(context);
        }
        if (tablet != null && width >= breakpoints.sm) {
          return tablet!(context);
        }
        return mobile(context);
      },
    );
  }
}
