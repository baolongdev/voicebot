import 'dart:async';

import 'package:flutter/widgets.dart' hide FormState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/forui/theme_tokens.dart';
import '../../../../di/locator.dart';
import '../../../../routing/routes.dart';
import '../../../../shared/widgets/responsive_builder.dart';

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
                Text('Cài đặt máy chủ', style: context.theme.typography.xl),
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
                _McpFlowCard(onOpen: () => context.go(Routes.mcpFlow)),
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
