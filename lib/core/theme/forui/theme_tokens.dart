class ThemeTokens {
  const ThemeTokens._();

  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;

  // Layout sizing tokens to avoid scattered magic numbers.
  static const double formWidthTablet = 480.0;
  static const double formWidthDesktop = 560.0;
  static const double paddingMobile = spaceLg;
  static const double paddingTablet = spaceXl;
  static const double paddingDesktop = spaceXl;
  static const double gapMobile = spaceSm;
  static const double gapTablet = spaceMd;
  static const double gapDesktop = spaceLg;
  static const double sectionGapMobile = spaceLg;
  static const double sectionGapTablet = spaceXl;
  static const double sectionGapDesktop = spaceXl;

  // Home layout sizing tokens for responsive content width.
  static const double homeWidthTablet = 480.0;
  static const double homeWidthDesktop = 720.0;
  static const double homePaddingMobile = spaceLg;
  static const double homePaddingTablet = spaceXl;
  static const double homePaddingDesktop = spaceXl;
  static const double homeSectionGapMobile = spaceMd;
  static const double homeSectionGapTablet = spaceLg;
  static const double homeSectionGapDesktop = spaceLg;
  static const double homeHeaderGapMobile = spaceSm;
  static const double homeHeaderGapTablet = spaceMd;
  static const double homeHeaderGapDesktop = spaceMd;

  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionBase = Duration(milliseconds: 250);
  static const Duration motionSlow = Duration(milliseconds: 400);
}
