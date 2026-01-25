import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../../di/locator.dart';
import '../../../../routing/routes.dart';
import '../../../form/domain/repositories/form_repository.dart';
import '../../../form/domain/repositories/form_result.dart';

class ActivationPage extends StatelessWidget {
  const ActivationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = getIt<FormRepository>();
    return FScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: StreamBuilder<FormResult?>(
            stream: repository.resultStream,
            initialData: repository.lastResult,
            builder: (context, snapshot) {
              final result = snapshot.data ?? repository.lastResult;
              final activation = result is XiaoZhiResult
                  ? result.otaResult?.activation
                  : null;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Kích hoạt',
                    style: context.theme.typography.xl,
                  ),
                  const SizedBox(height: 12.0),
                  if (activation == null) ...[
                    Text(
                      'Chưa có mã kích hoạt.',
                      textAlign: TextAlign.center,
                      style: context.theme.typography.base.copyWith(
                        color: context.theme.colors.muted,
                      ),
                    ),
                  ] else ...[
                    Text(
                      activation.code,
                      style: context.theme.typography.xl,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      activation.message,
                      textAlign: TextAlign.center,
                      style: context.theme.typography.base,
                    ),
                    const SizedBox(height: 16.0),
                    FButton(
                      onPress: () => context.go(Routes.chat),
                      child: const Text('Continue to chat'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
