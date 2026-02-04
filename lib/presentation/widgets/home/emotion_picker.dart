import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/forui/theme_tokens.dart';
import 'emotion_palette.dart';

class EmotionPicker extends StatefulWidget {
  const EmotionPicker({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.palette,
  });

  final List<String> options;
  final int selectedIndex;
  final EmotionPalette palette;

  @override
  State<EmotionPicker> createState() => _EmotionPickerState();
}

class _EmotionPickerState extends State<EmotionPicker> {
  static const double _itemSpacing = ThemeTokens.spaceXs;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    if (widget.options.isEmpty) {
      return const SizedBox.shrink();
    }
    final textScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.5);
    final baseHeight = ThemeTokens.buttonHeight - ThemeTokens.spaceXs;
    final height = (baseHeight * textScale).clamp(baseHeight, 72.0);
    final visibleCount = textScale > 1.0 ? 3 : 5;
    final centerSlot = visibleCount ~/ 2;
    final horizontalPadding = (ThemeTokens.spaceSm * textScale).clamp(
      ThemeTokens.spaceSm,
      ThemeTokens.spaceMd,
    );
    final verticalPadding = (ThemeTokens.spaceXs * textScale).clamp(
      ThemeTokens.spaceXs,
      ThemeTokens.spaceSm,
    );
    return Container(
      padding: const EdgeInsets.all(ThemeTokens.spaceXs),
      decoration: BoxDecoration(
        color: palette.controlBackground(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemExtent = _resolveItemExtent(
              context,
              constraints.maxWidth,
              textScale,
              visibleCount,
            );
            final length = widget.options.length;
            final selected = widget.selectedIndex.clamp(0, length - 1);
            final children = <Widget>[];
            for (var slot = 0; slot < visibleCount; slot++) {
              if (slot > 0) {
                children.add(const SizedBox(width: _itemSpacing));
              }
              final offset = slot - centerSlot;
              final index = (selected + offset + length) % length;
              final isSelected = offset == 0;
                final scale = isSelected ? 1.0 : 0.96;
                final opacity = isSelected ? 1.0 : 0.72;
              children.add(
                SizedBox(
                  width: itemExtent,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    scale: scale,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      opacity: opacity,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? palette.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: palette.accent.withAlpha(90),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          style: context.theme.typography.base.copyWith(
                            color: isSelected
                                ? palette.accentForeground
                                : palette.controlForeground(context),
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          child: Text(
                            widget.options[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            strutStyle: const StrutStyle(
                              height: 1.0,
                              forceStrutHeight: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            );
          },
        ),
      ),
    );
  }

  double _resolveItemExtent(
    BuildContext context,
    double maxWidth,
    double textScale,
    int visibleCount,
  ) {
    final totalSpacing = _itemSpacing * (visibleCount - 1);
    final raw = (maxWidth - totalSpacing) / visibleCount;
    return raw < 0 ? 0 : raw;
  }
}
