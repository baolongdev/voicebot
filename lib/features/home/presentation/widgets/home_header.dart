import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.gap,
    this.alignment = Alignment.center,
    this.textAlign = TextAlign.center,
  });

  final String title;
  final String subtitle;
  final double gap;
  final Alignment alignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment =
        alignment == Alignment.center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Align(
      alignment: alignment,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            title,
            textAlign: textAlign,
            style: context.theme.typography.xl,
          ),
          SizedBox(height: gap),
          Text(
            subtitle,
            textAlign: textAlign,
            style: context.theme.typography.base.copyWith(
              color: context.theme.colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
