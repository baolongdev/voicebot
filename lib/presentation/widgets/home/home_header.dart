import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/forui/theme_tokens.dart';
import '../../../theme/theme_extensions.dart';
import '../ui_scale.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.now,
    required this.onOpenSettings,
    required this.onCheckUpdate,
  });

  final DateTime now;
  final VoidCallback onOpenSettings;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    final dateText =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeText =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    final headerTextColor = context.theme.brand.headerForeground;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.spaceSm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.typography.base.copyWith(
                    color: headerTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  timeText,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.typography.base.copyWith(
                    color: headerTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FButton.icon(
                        onPress: onCheckUpdate,
                        style: FButtonStyle.ghost(
                          (style) => style.copyWith(
                            contentStyle: (content) => content.copyWith(
                              padding: const EdgeInsets.symmetric(
                                horizontal: ThemeTokens.spaceXs,
                                vertical: 2,
                              ),
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.system_update_alt_rounded,
                          size: scaledIconSize(context, 18),
                          color: headerTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      FButton.icon(
                        onPress: onOpenSettings,
                        style: FButtonStyle.ghost(
                          (style) => style.copyWith(
                            contentStyle: (content) => content.copyWith(
                              padding: const EdgeInsets.symmetric(
                                horizontal: ThemeTokens.spaceXs,
                                vertical: 2,
                              ),
                            ),
                          ),
                        ),
                        child: Icon(
                          FIcons.bolt,
                          size: scaledIconSize(context, 18),
                          color: headerTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
