import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LucideBoltIcon extends StatelessWidget {
  const LucideBoltIcon({
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
    super.key,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.string(
      _boltSvg(strokeWidth),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }

  String _boltSvg(double strokeWidth) {
    return '''
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">
  <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
</svg>
''';
  }
}
