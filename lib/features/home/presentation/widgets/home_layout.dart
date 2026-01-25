import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/forui/theme_tokens.dart';
import '../../../../routing/routes.dart';
import '../../../../shared/widgets/responsive_builder.dart';
import 'home_header.dart';

class HomeLayout extends StatelessWidget {
  const HomeLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: ResponsiveBuilder(
        mobile: (context) => _HomeShell(
          maxWidth: double.infinity,
          padding: ThemeTokens.homePaddingMobile,
          headerGap: ThemeTokens.spaceSm,
          sectionGap: ThemeTokens.homeSectionGapMobile,
        ),
        tablet: (context) => _HomeShell(
          maxWidth: ThemeTokens.homeWidthTablet,
          padding: ThemeTokens.homePaddingTablet,
          headerGap: ThemeTokens.spaceMd,
          sectionGap: ThemeTokens.homeSectionGapTablet,
        ),
        desktop: (context) => _HomeShell(
          maxWidth: ThemeTokens.homeWidthDesktop,
          padding: ThemeTokens.homePaddingDesktop,
          headerGap: ThemeTokens.spaceMd,
          sectionGap: ThemeTokens.homeSectionGapDesktop,
        ),
      ),
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({
    required this.maxWidth,
    required this.padding,
    required this.headerGap,
    required this.sectionGap,
  });

  final double maxWidth;
  final double padding;
  final double headerGap;
  final double sectionGap;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeHeader(
                  title: 'VoiceBot',
                  subtitle: 'Configure your server, then start chatting.',
                  gap: headerGap,
                  alignment: Alignment.center,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: sectionGap),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FButton(
                    onPress: () => context.go(Routes.form),
                    child: const Text('Configure Server'),
                  ),
                ),
                SizedBox(height: ThemeTokens.spaceSm),
                Text(
                  'Tap to get started',
                  textAlign: TextAlign.center,
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.muted,
                  ),
                ),
                SizedBox(height: ThemeTokens.spaceLg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
