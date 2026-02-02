import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/forui/theme_tokens.dart';

class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            SizedBox(height: ThemeTokens.spaceSm),
            Text(description),
            SizedBox(height: ThemeTokens.spaceLg),
            Semantics(
              button: true,
              label: title,
              child: SizedBox(
                height: ThemeTokens.buttonHeight,
                child: FButton(onPress: onPressed, child: const Text('Open')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
