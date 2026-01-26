import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../domain/models/server_form_data.dart';

class ServerConfigSection extends StatelessWidget {
  const ServerConfigSection({
    super.key,
    required this.serverType,
    required this.xiaoZhiConfig,
    required this.selfHostConfig,
    required this.errors,
    required this.fieldGap,
    required this.onXiaoZhiUpdate,
    required this.onSelfHostUpdate,
  });

  final ServerType serverType;
  final XiaoZhiConfig xiaoZhiConfig;
  final SelfHostConfig selfHostConfig;
  final Map<String, String> errors;
  final double fieldGap;
  final ValueChanged<XiaoZhiConfig> onXiaoZhiUpdate;
  final ValueChanged<SelfHostConfig> onSelfHostUpdate;

  @override
  Widget build(BuildContext context) {
    return switch (serverType) {
      ServerType.xiaoZhi => _XiaoZhiSection(
          config: xiaoZhiConfig,
          errors: errors,
          fieldGap: fieldGap,
          onUpdate: onXiaoZhiUpdate,
        ),
      ServerType.selfHost => _SelfHostSection(
          config: selfHostConfig,
          errors: errors,
          fieldGap: fieldGap,
          onUpdate: onSelfHostUpdate,
        ),
    };
  }
}

class _XiaoZhiSection extends StatelessWidget {
  const _XiaoZhiSection({
    required this.config,
    required this.errors,
    required this.fieldGap,
    required this.onUpdate,
  });

  final XiaoZhiConfig config;
  final Map<String, String> errors;
  final double fieldGap;
  final ValueChanged<XiaoZhiConfig> onUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FocusTraversalOrder(
          order: const NumericFocusOrder(2.0),
          child: Semantics(
            textField: true,
            label: 'WebSocket URL',
            child: FTextField(
              label: const Text('WebSocket URL'),
              keyboardType: TextInputType.url,
              error: _errorText(errors['xiaoZhiWebSocketUrl']),
              control: FTextFieldControl.lifted(
                value: TextEditingValue(
                  text: config.webSocketUrl,
                  selection: TextSelection.collapsed(
                    offset: config.webSocketUrl.length,
                  ),
                ),
                onChange: (value) {
                  onUpdate(
                    XiaoZhiConfig(
                      webSocketUrl: value.text,
                      qtaUrl: config.qtaUrl,
                      transportType: config.transportType,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(height: fieldGap),
        FocusTraversalOrder(
          order: const NumericFocusOrder(3.0),
          child: Semantics(
            textField: true,
            label: 'QTA URL',
            child: FTextField(
              label: const Text('QTA URL'),
              keyboardType: TextInputType.url,
              error: _errorText(errors['qtaUrl']),
              control: FTextFieldControl.lifted(
                value: TextEditingValue(
                  text: config.qtaUrl,
                  selection: TextSelection.collapsed(
                    offset: config.qtaUrl.length,
                  ),
                ),
                onChange: (value) {
                  onUpdate(
                    XiaoZhiConfig(
                      webSocketUrl: config.webSocketUrl,
                      qtaUrl: value.text,
                      transportType: config.transportType,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(height: fieldGap),
        Text(
          'Loại truyền tải',
          style: context.theme.typography.base,
        ),
        SizedBox(height: fieldGap),
        FocusTraversalOrder(
          order: const NumericFocusOrder(3.5),
          child: FSelectGroup<TransportType>(
            control: FMultiValueControl.lifted(
              value: {config.transportType},
              onChange: (value) {
                final next = _resolveNext(value, config.transportType);
                if (next != config.transportType) {
                  onUpdate(
                    XiaoZhiConfig(
                      webSocketUrl: config.webSocketUrl,
                      qtaUrl: config.qtaUrl,
                      transportType: next,
                    ),
                  );
                }
              },
            ),
            children: TransportType.values.map((type) {
              return FSelectGroupItemMixin.radio<TransportType>(
                value: type,
                label: Text(_transportLabel(type)),
                semanticsLabel: _transportLabel(type),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget? _errorText(String? message) {
    if (message == null) {
      return null;
    }
    return Text(message);
  }

  String _transportLabel(TransportType type) {
    return switch (type) {
      TransportType.mqtt => 'MQTT',
      TransportType.webSockets => 'WebSockets',
    };
  }

  TransportType _resolveNext(Set<TransportType> value, TransportType current) {
    if (value.isEmpty) {
      return current;
    }
    if (value.length == 1) {
      return value.first;
    }
    return value.firstWhere((entry) => entry != current, orElse: () => current);
  }
}

class _SelfHostSection extends StatelessWidget {
  const _SelfHostSection({
    required this.config,
    required this.errors,
    required this.fieldGap,
    required this.onUpdate,
  });

  final SelfHostConfig config;
  final Map<String, String> errors;
  final double fieldGap;
  final ValueChanged<SelfHostConfig> onUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FocusTraversalOrder(
          order: const NumericFocusOrder(2.0),
          child: Semantics(
            textField: true,
            label: 'WebSocket URL',
            child: FTextField(
              label: const Text('WebSocket URL'),
              keyboardType: TextInputType.url,
              error: _errorText(errors['selfHostWebSocketUrl']),
              control: FTextFieldControl.lifted(
                value: TextEditingValue(
                  text: config.webSocketUrl,
                  selection: TextSelection.collapsed(
                    offset: config.webSocketUrl.length,
                  ),
                ),
                onChange: (value) {
                  onUpdate(
                    SelfHostConfig(
                      webSocketUrl: value.text,
                      transportType: config.transportType,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(height: fieldGap),
        Text(
          'Loại truyền tải: WebSockets (cố định)',
          style: context.theme.typography.base,
        ),
      ],
    );
  }

  Widget? _errorText(String? message) {
    if (message == null) {
      return null;
    }
    return Text(message);
  }
}
