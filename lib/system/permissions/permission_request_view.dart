import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';

import 'package:voicebot/core/permissions/permission_copy.dart';
import 'package:voicebot/core/theme/forui/theme_tokens.dart';
import 'package:voicebot/system/permissions/permission_notifier.dart';
import 'package:voicebot/system/permissions/permission_state.dart';

class PermissionRequestView extends StatelessWidget {
  const PermissionRequestView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionCubit, PermissionState>(
      builder: (context, state) {
        return FScaffold(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ThemeTokens.homeWidthTablet,
              ),
              child: FCard(
                child: Padding(
                  padding: const EdgeInsets.all(ThemeTokens.spaceLg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(PermissionCopy.title),
                      const SizedBox(height: ThemeTokens.spaceSm),
                      const Text(PermissionCopy.description),
                      const SizedBox(height: ThemeTokens.spaceLg),
                      FButton(
                        onPress: state.isChecking
                            ? null
                            : () => context
                                .read<PermissionCubit>()
                                .requestRequiredPermissions(),
                        child: state.isChecking
                            ? const FCircularProgress()
                            : const Text(PermissionCopy.action),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
