import 'package:flutter/widgets.dart';

class ControlsExamples extends StatelessWidget {
  const ControlsExamples({super.key});

  static const String liftedControlExample = '''
// Lifted control (state in Bloc/Riverpod)
// - UI reads value from state
// - UI emits event without owning controller
//
// Widget build(...) {
//   final email = state.email;
//   return FTextInput(
//     value: email,
//     onChanged: (value) => bloc.add(AuthEmailChanged(value)),
//   );
// }
''';

  static const String managedControlExample = '''
// Managed control (internal/external)
// - Internal: widget owns control for simple local state
// - External: parent orchestrates when needed
//
// class _ExampleState extends State<Example> {
//   late final FPopoverController _popover = FPopoverController();
//   @override
//   Widget build(...) {
//     return FPopover(
//       controller: _popover,
//       child: ...,
//     );
//   }
// }
''';

  static const String hooksGuideline = '''
// Hooks (optional)
// - If flutter_hooks is used, prefer forui_hooks for Accordion/Popover/Disclosure
// - Otherwise, use managed controls internal to the widget
''';

  @override
  Widget build(BuildContext context) {
    // Intentionally empty: this file is for guideline examples only.
    return const SizedBox.shrink();
  }
}
