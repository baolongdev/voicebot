import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/forui/theme_tokens.dart';
import '../../../../shared/widgets/responsive_builder.dart';

typedef LoginFormBuilder = Widget Function(
  BuildContext context,
  LoginLayoutMetrics metrics,
);

class LoginLayoutMetrics {
  const LoginLayoutMetrics({
    required this.fieldGap,
    required this.sectionGap,
    required this.padding,
    required this.maxWidth,
  });

  final double fieldGap;
  final double sectionGap;
  final double padding;
  final double maxWidth;
}

class LoginLayout extends StatelessWidget {
  const LoginLayout({super.key, required this.formBuilder});

  final LoginFormBuilder formBuilder;

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: ResponsiveBuilder(
        mobile: (context) => _MobileLayout(
          formBuilder: formBuilder,
          metrics: const LoginLayoutMetrics(
            fieldGap: ThemeTokens.gapMobile,
            sectionGap: ThemeTokens.sectionGapMobile,
            padding: ThemeTokens.paddingMobile,
            maxWidth: double.infinity,
          ),
        ),
        tablet: (context) => _CenteredCardLayout(
          formBuilder: formBuilder,
          metrics: const LoginLayoutMetrics(
            fieldGap: ThemeTokens.gapTablet,
            sectionGap: ThemeTokens.sectionGapTablet,
            padding: ThemeTokens.paddingTablet,
            maxWidth: ThemeTokens.formWidthTablet,
          ),
        ),
        desktop: (context) => _SplitLayout(
          formBuilder: formBuilder,
          metrics: const LoginLayoutMetrics(
            fieldGap: ThemeTokens.gapDesktop,
            sectionGap: ThemeTokens.sectionGapDesktop,
            padding: ThemeTokens.paddingDesktop,
            maxWidth: ThemeTokens.formWidthDesktop,
          ),
        ),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.formBuilder, required this.metrics});

  final LoginFormBuilder formBuilder;
  final LoginLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    // Reduce density on small screens without shrinking touch targets.
    return Padding(
      padding: EdgeInsets.all(metrics.padding),
      child: formBuilder(context, metrics),
    );
  }
}

class _CenteredCardLayout extends StatelessWidget {
  const _CenteredCardLayout({required this.formBuilder, required this.metrics});

  final LoginFormBuilder formBuilder;
  final LoginLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: metrics.maxWidth),
        child: FCard(
          child: Padding(
            padding: EdgeInsets.all(metrics.padding),
            child: formBuilder(context, metrics),
          ),
        ),
      ),
    );
  }
}

class _SplitLayout extends StatelessWidget {
  const _SplitLayout({required this.formBuilder, required this.metrics});

  final LoginFormBuilder formBuilder;
  final LoginLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: SizedBox.shrink()),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: metrics.maxWidth),
              child: FCard(
                child: Padding(
                  padding: EdgeInsets.all(metrics.padding),
                  child: formBuilder(context, metrics),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
