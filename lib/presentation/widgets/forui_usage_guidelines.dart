class ForuiUsageGuidelines {
  const ForuiUsageGuidelines._();

  // Use Forui widgets when they provide interaction/semantics/style defaults
  // that should stay consistent across the app (buttons, inputs, cards).
  static const String useForui = 'Use Forui for components with interaction or '
      'visual system ownership (e.g., FButton, FTextField, FCard, FDivider).';

  // Use Flutter layout widgets for structure; Forui does not replace layout.
  static const String useFlutterLayout = 'Use Flutter layout widgets for '
      'structure (Row, Column, Padding, SizedBox).';

  // Avoid wrapping Flutter widgets just to mimic Forui; prefer direct Forui
  // widgets when they exist to keep behaviors consistent.
  static const String avoidRedundantWrappers = 'Do not wrap Flutter widgets '
      'when a Forui component already exists for that role.';
}
