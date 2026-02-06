import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../capabilities/mcp/mcp_server.dart';
import '../../core/theme/forui/theme_tokens.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/responsive_builder.dart';

class McpFlowPage extends StatelessWidget {
  McpFlowPage({super.key});

  final McpServer _mcpServer = McpServer(controller: _CatalogMcpController());

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: SafeArea(
        child: ResponsiveBuilder(
          mobile: (_) => _buildBody(
            context,
            padding: ThemeTokens.paddingMobile,
            maxWidth: double.infinity,
            sectionGap: ThemeTokens.sectionGapMobile,
          ),
          tablet: (_) => _buildBody(
            context,
            padding: ThemeTokens.paddingTablet,
            maxWidth: ThemeTokens.formWidthTablet,
            sectionGap: ThemeTokens.sectionGapTablet,
          ),
          desktop: (_) => _buildBody(
            context,
            padding: ThemeTokens.paddingDesktop,
            maxWidth: ThemeTokens.formWidthDesktop,
            sectionGap: ThemeTokens.sectionGapDesktop,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required double padding,
    required double maxWidth,
    required double sectionGap,
  }) {
    final commonTools = _mcpServer.tools.where((tool) => !tool.userOnly).toList();
    final userOnlyTools = _mcpServer.tools.where((tool) => tool.userOnly).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FButton(
                onPress: () => context.go(Routes.home),
                style: FButtonStyle.ghost(
                  (style) => style.copyWith(
                    contentStyle: (content) => content.copyWith(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ThemeTokens.spaceSm,
                        vertical: ThemeTokens.spaceXs,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      size: 18,
                      color: context.theme.colors.foreground,
                    ),
                    const SizedBox(width: ThemeTokens.spaceXs),
                    Text(
                      'Quay lai Home',
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ThemeTokens.spaceSm),
              Text(
                'MCP Manager',
                style: context.theme.typography.xl.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ThemeTokens.spaceSm),
              Text(
                'Danh sach tool MCP dang co, quyen su dung va cach goi.',
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              SizedBox(height: sectionGap),
              _SectionCard(
                title: 'Quick Start',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bullet(context, '1. Goi initialize de bat tay MCP.'),
                    _bullet(context, '2. Goi tools/list de lay danh sach tools.'),
                    _bullet(context, '3. Goi tools/call theo tung tool name.'),
                    const SizedBox(height: ThemeTokens.spaceSm),
                    _codeBlock(
                      context,
                      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{"tools":{}}}}',
                    ),
                  ],
                ),
              ),
              SizedBox(height: sectionGap),
              _SectionCard(
                title: 'Common Tools (AI + User)',
                child: _buildToolList(
                  context,
                  commonTools,
                  audienceLabel: 'ai + user',
                ),
              ),
              SizedBox(height: sectionGap),
              _SectionCard(
                title: 'User-only Tools',
                child: _buildToolList(
                  context,
                  userOnlyTools,
                  audienceLabel: 'user-only',
                ),
              ),
              SizedBox(height: sectionGap),
              _SectionCard(
                title: 'Mau Request',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bullet(context, 'tools/list:'),
                    const SizedBox(height: ThemeTokens.spaceXs),
                    _codeBlock(
                      context,
                      '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{"cursor":"","withUserTools":true}}',
                    ),
                    const SizedBox(height: ThemeTokens.spaceSm),
                    _bullet(context, 'tools/call:'),
                    const SizedBox(height: ThemeTokens.spaceXs),
                    _codeBlock(
                      context,
                      '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"self.audio_speaker.set_volume","arguments":{"volume":20}}}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.theme.typography.base.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceSm),
            child,
          ],
        ),
      ),
    );
  }
}

Widget _buildToolList(
  BuildContext context,
  List<McpTool> tools, {
  required String audienceLabel,
}) {
  if (tools.isEmpty) {
    return Text(
      'Chua co tool.',
      style: context.theme.typography.sm.copyWith(
        color: context.theme.colors.mutedForeground,
      ),
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final tool in tools) ...[
        _ToolItem(
          tool: tool,
          audienceLabel: audienceLabel,
        ),
        if (tool != tools.last) const SizedBox(height: ThemeTokens.spaceMd),
      ],
    ],
  );
}

class _ToolItem extends StatelessWidget {
  const _ToolItem({
    required this.tool,
    required this.audienceLabel,
  });

  final McpTool tool;
  final String audienceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThemeTokens.spaceSm),
      decoration: BoxDecoration(
        border: Border.all(color: context.theme.colors.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tool.name,
            style: context.theme.typography.base.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ThemeTokens.spaceXs),
          Text(
            'Audience: $audienceLabel',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: ThemeTokens.spaceXs),
          Text(
            tool.description,
            style: context.theme.typography.sm,
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          Text(
            tool.properties.isEmpty
                ? 'Params: none'
                : 'Params: ${tool.properties.map(_propertyLabel).join(', ')}',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          _codeBlock(context, _toolCallExample(tool)),
        ],
      ),
    );
  }
}

String _propertyLabel(McpProperty property) {
  final type = switch (property.type) {
    McpPropertyType.boolean => 'bool',
    McpPropertyType.integer => 'int',
    McpPropertyType.string => 'string',
  };
  if (property.type == McpPropertyType.integer &&
      property.minValue != null &&
      property.maxValue != null) {
    return '${property.name}:$type(${property.minValue}-${property.maxValue})';
  }
  return '${property.name}:$type';
}

String _toolCallExample(McpTool tool) {
  final args = <String, dynamic>{};
  for (final prop in tool.properties) {
    switch (prop.type) {
      case McpPropertyType.boolean:
        args[prop.name] = prop.defaultValue ?? false;
      case McpPropertyType.integer:
        args[prop.name] = prop.defaultValue ?? prop.minValue ?? 0;
      case McpPropertyType.string:
        args[prop.name] = prop.defaultValue ?? 'value';
    }
  }

  final encodedArgs = args.entries.map((entry) {
    final value = entry.value;
    if (value is String) {
      return '"${entry.key}":"$value"';
    }
    return '"${entry.key}":$value';
  }).join(',');

  return '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"${tool.name}","arguments":{$encodedArgs}}}';
}

Widget _bullet(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: ThemeTokens.spaceXs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '-',
          style: context.theme.typography.sm.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(width: ThemeTokens.spaceSm),
        Expanded(
          child: Text(
            text,
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.foreground,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _codeBlock(BuildContext context, String code) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(ThemeTokens.spaceSm),
    decoration: BoxDecoration(
      color: context.theme.colors.muted,
      borderRadius: BorderRadius.circular(ThemeTokens.radiusSm),
      border: Border.all(color: context.theme.colors.border),
    ),
    child: Text(
      code,
      style: context.theme.typography.sm.copyWith(
        fontFamily: 'monospace',
        height: 1.35,
      ),
    ),
  );
}

class _CatalogMcpController implements McpDeviceController {
  @override
  Future<Map<String, dynamic>> getDeviceStatus() async {
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getSystemInfo() async {
    return <String, dynamic>{};
  }

  @override
  Future<bool> setSpeakerVolume(int percent) async {
    return true;
  }
}
