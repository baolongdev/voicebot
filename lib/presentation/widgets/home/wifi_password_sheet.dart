import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/forui/theme_tokens.dart';
import '../../../features/home/domain/entities/home_wifi_network.dart';

class WifiPasswordSheet extends StatelessWidget {
  const WifiPasswordSheet({
    super.key,
    required this.network,
    required this.password,
    required this.onPasswordChanged,
    required this.onConnect,
    required this.onCancel,
    required this.isConnecting,
  });

  final HomeWifiNetwork network;
  final String password;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback? onConnect;
  final VoidCallback onCancel;
  final bool isConnecting;

  @override
  Widget build(BuildContext context) {
    final needsPassword = network.secured;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              ThemeTokens.spaceMd,
              0,
              ThemeTokens.spaceMd,
              ThemeTokens.spaceMd,
            ),
            decoration: BoxDecoration(
              color: context.theme.colors.background,
              borderRadius: BorderRadius.circular(ThemeTokens.radiusLg),
              border: Border.all(color: context.theme.colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ThemeTokens.spaceLg,
                ThemeTokens.spaceMd,
                ThemeTokens.spaceLg,
                ThemeTokens.spaceLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    network.ssid,
                    style: context.theme.typography.xl.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: ThemeTokens.spaceXs),
                  Text(
                    needsPassword
                        ? 'Nhập mật khẩu để kết nối.'
                        : 'Mạng mở, không cần mật khẩu.',
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: ThemeTokens.spaceMd),
                  if (needsPassword)
                    FTextField(
                      label: const Text('Mật khẩu'),
                      obscureText: true,
                      control: FTextFieldControl.lifted(
                        value: TextEditingValue(
                          text: password,
                          selection: TextSelection.collapsed(
                            offset: password.length,
                          ),
                        ),
                        onChange: (value) => onPasswordChanged(value.text),
                      ),
                    ),
                  const SizedBox(height: ThemeTokens.spaceLg),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: ThemeTokens.buttonHeight,
                          child: FButton(
                            onPress: onCancel,
                            style: FButtonStyle.ghost(),
                            child: const Text('Từ chối'),
                          ),
                        ),
                      ),
                      const SizedBox(width: ThemeTokens.spaceSm),
                      Expanded(
                        child: SizedBox(
                          height: ThemeTokens.buttonHeight,
                          child: FButton(
                            onPress: needsPassword && password.isEmpty
                                ? null
                                : onConnect,
                            child: isConnecting
                                ? const FCircularProgress()
                                : const Text('Kết nối'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
