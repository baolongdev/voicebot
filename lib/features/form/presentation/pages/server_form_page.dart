import 'dart:async';

import 'package:flutter/widgets.dart' hide FormState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/forui/theme_tokens.dart';
import '../../../../di/locator.dart';
import '../../../../routing/routes.dart';
import '../../../../shared/widgets/responsive_builder.dart';
import '../../domain/models/server_form_data.dart';
import '../../domain/repositories/form_result.dart';
import '../state/form_state.dart' as form;
import '../widgets/server_config_section.dart';
import '../widgets/server_type_section.dart';

class ServerFormPage extends StatelessWidget {
  const ServerFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<form.FormBloc>(
      create: (_) => getIt<form.FormBloc>(),
      child: const _ServerFormView(),
    );
  }
}

class _ServerFormView extends StatefulWidget {
  const _ServerFormView();

  @override
  State<_ServerFormView> createState() => _ServerFormViewState();
}

class _ServerFormViewState extends State<_ServerFormView> {
  StreamSubscription<String>? _navigationSubscription;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<form.FormBloc>();
    _navigationSubscription = bloc.navigationStream.listen((route) {
      if (!mounted) {
        return;
      }
      final target = _mapRoute(route);
      if (target != null) {
        context.go(target);
      }
    });
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    super.dispose();
  }

  String? _mapRoute(String route) {
    switch (route) {
      case 'chat':
        return Routes.chat;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: BlocBuilder<form.FormBloc, form.FormState>(
        builder: (context, state) {
          return ResponsiveBuilder(
            mobile: (_) => _buildBody(
              context,
              state,
              padding: ThemeTokens.spaceMd,
              sectionGap: ThemeTokens.spaceLg,
              fieldGap: ThemeTokens.spaceMd,
              maxWidth: double.infinity,
            ),
            tablet: (_) => _buildBody(
              context,
              state,
              padding: ThemeTokens.spaceLg,
              sectionGap: ThemeTokens.spaceXl,
              fieldGap: ThemeTokens.spaceMd,
              maxWidth: ThemeTokens.formWidthTablet,
            ),
            desktop: (_) => _buildBody(
              context,
              state,
              padding: ThemeTokens.spaceLg,
              sectionGap: ThemeTokens.spaceXl,
              fieldGap: ThemeTokens.spaceMd,
              maxWidth: ThemeTokens.formWidthDesktop,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    form.FormState state, {
    required double padding,
    required double sectionGap,
    required double fieldGap,
    required double maxWidth,
  }) {
    final bloc = context.read<form.FormBloc>();
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ServerTypeSection(
                  selectedType: state.formData.serverType,
                  onTypeSelected: (value) =>
                      bloc.add(form.FormServerTypeChanged(value)),
                  sectionGap: fieldGap,
                ),
                SizedBox(height: sectionGap),
                Text(
                  'Cài đặt máy chủ',
                  style: context.theme.typography.xl,
                ),
                SizedBox(height: fieldGap),
                ServerConfigSection(
                  serverType: state.formData.serverType,
                  xiaoZhiConfig: state.formData.xiaoZhiConfig,
                  selfHostConfig: state.formData.selfHostConfig,
                  errors: state.validationResult.errors,
                  fieldGap: fieldGap,
                  onXiaoZhiUpdate: (config) =>
                      bloc.add(form.FormXiaoZhiConfigChanged(config)),
                  onSelfHostUpdate: (config) =>
                      bloc.add(form.FormSelfHostConfigChanged(config)),
                ),
                SizedBox(height: sectionGap),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(4.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: ThemeTokens.buttonHeight,
                    child: FButton(
                      onPress: state.isLoading
                          ? null
                          : () => bloc.add(const form.FormSubmitted()),
                      child: const Text('Kết nối'),
                    ),
                  ),
                ),
                SizedBox(height: fieldGap),
                _StatusMessage(uiState: state.uiState),
                SizedBox(height: sectionGap),
                _DebugPanel(
                  formData: state.formData,
                  validationErrors: state.validationResult.errors,
                  uiState: state.uiState,
                  lastResult: state.lastResult,
                ),
                SizedBox(height: sectionGap),
                _McpFlowCard(
                  onOpen: () => context.go(Routes.mcpFlow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.uiState});

  final form.FormUiState uiState;

  @override
  Widget build(BuildContext context) {
    switch (uiState.status) {
      case form.FormUiStatus.loading:
        return Semantics(
          liveRegion: true,
          label: 'Loading',
          child: const Center(child: FCircularProgress()),
        );
      case form.FormUiStatus.success:
        return Text(
          uiState.message ?? '',
          textAlign: TextAlign.center,
          style: context.theme.typography.sm.copyWith(
            color: context.theme.colors.primary,
          ),
        );
      case form.FormUiStatus.error:
        return Semantics(
          liveRegion: true,
          label: uiState.message ?? '',
          child: Text(
            uiState.message ?? '',
            textAlign: TextAlign.center,
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.error,
            ),
          ),
        );
      case form.FormUiStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({
    required this.formData,
    required this.validationErrors,
    required this.uiState,
    required this.lastResult,
  });

  final ServerFormData formData;
  final Map<String, String> validationErrors;
  final form.FormUiState uiState;
  final FormResult? lastResult;

  @override
  Widget build(BuildContext context) {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dữ liệu gửi',
              style: context.theme.typography.base,
            ),
            const SizedBox(height: 8.0),
            _InfoRow(label: 'Loại', value: formData.serverType.name),
            _InfoRow(
              label: 'WebSocket',
              value: _webSocketUrl(formData),
            ),
            if (formData.serverType == ServerType.xiaoZhi)
              _InfoRow(
                label: 'QTA',
                value: formData.xiaoZhiConfig.qtaUrl,
              ),
            _InfoRow(
              label: 'Truyền tải',
              value: _transportType(formData),
            ),
            const SizedBox(height: 12.0),
            Text(
              'Trạng thái',
              style: context.theme.typography.base,
            ),
            const SizedBox(height: 8.0),
            _InfoRow(
              label: 'UI',
              value: uiState.status.name,
            ),
            if (uiState.message != null && uiState.message!.isNotEmpty)
              _InfoRow(
                label: 'Thông báo',
                value: uiState.message!,
              ),
            if (validationErrors.isNotEmpty) ...[
              const SizedBox(height: 12.0),
              Text(
                'Lỗi kiểm tra',
                style: context.theme.typography.base,
              ),
              const SizedBox(height: 8.0),
              ...validationErrors.entries.map(
                (entry) => _InfoRow(
                  label: entry.key,
                  value: entry.value,
                ),
              ),
            ],
            const SizedBox(height: 12.0),
            Text(
              'Kết quả trả về',
              style: context.theme.typography.base,
            ),
            const SizedBox(height: 8.0),
            ..._resultLines(lastResult).map(
              (line) => _InfoRow(label: line.$1, value: line.$2),
            ),
          ],
        ),
      ),
    );
  }

  String _webSocketUrl(ServerFormData data) {
    return data.serverType == ServerType.xiaoZhi
        ? data.xiaoZhiConfig.webSocketUrl
        : data.selfHostConfig.webSocketUrl;
  }

  String _transportType(ServerFormData data) {
    return data.serverType == ServerType.xiaoZhi
        ? data.xiaoZhiConfig.transportType.name
        : data.selfHostConfig.transportType.name;
  }

  List<(String, String)> _resultLines(FormResult? result) {
    if (result == null) {
      return const [('Kết quả', 'Chưa có')];
    }
    if (result is SelfHostResult) {
      return const [('Loại', 'SelfHost')];
    }
    if (result is XiaoZhiResult) {
      final ota = result.otaResult;
      return [
        const ('Loại', 'XiaoZhi'),
        ('Firmware', ota?.firmware?.version ?? '-'),
        ('Firmware URL', ota?.firmware?.url ?? '-'),
        ('Activation', ota?.activation?.code ?? '-'),
        ('MQTT Endpoint', ota?.mqttConfig.endpoint ?? '-'),
        ('MQTT ClientId', ota?.mqttConfig.clientId ?? '-'),
      ];
    }
    return const [('Kết quả', 'Không xác định')];
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.theme.typography.sm,
            ),
          ),
        ],
      ),
    );
  }
}

class _McpFlowCard extends StatelessWidget {
  const _McpFlowCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MCP Server Flow',
              style: context.theme.typography.base.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceSm),
            Text(
              'Xem chi tiết luồng JSON‑RPC 2.0 và danh sách tools.',
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceMd),
            SizedBox(
              height: ThemeTokens.buttonHeight,
              child: FButton(
                onPress: onOpen,
                child: const Text('Mở MCP Server Flow'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
