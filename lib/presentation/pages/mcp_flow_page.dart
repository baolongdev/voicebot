import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../capabilities/mcp/mcp_server.dart';
import '../../core/theme/forui/theme_tokens.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/responsive_builder.dart';
import '../../theme/theme_extensions.dart';

class McpFlowPage extends StatefulWidget {
  const McpFlowPage({super.key});

  @override
  State<McpFlowPage> createState() => _McpFlowPageState();
}

class _McpFlowPageState extends State<McpFlowPage> {
  final McpServer _mcpServer = McpServer.shared;

  final int _topKDefault = 5;
  int _requestId = 1000;

  bool _isBusy = false;
  String? _statusText;
  bool _statusIsError = false;

  String _textDocName = '';
  String _textDocContent = '';
  String _filePath = '';
  String _fileAlias = '';
  String _query = '';

  List<Map<String, dynamic>> _documents = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _searchResults = <Map<String, dynamic>>[];
  bool _searchAttempted = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      _runAction(() async {
        await _loadDocuments();
      }, successMessage: null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commonTools =
        _mcpServer.tools.where((tool) => !tool.userOnly).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final userOnlyTools =
        _mcpServer.tools.where((tool) => tool.userOnly).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return FScaffold(
      child: SafeArea(
        child: ResponsiveBuilder(
          mobile: (_) => _buildPage(
            context,
            padding: ThemeTokens.paddingMobile,
            sectionGap: ThemeTokens.sectionGapMobile + ThemeTokens.spaceSm,
            commonTools: commonTools,
            userOnlyTools: userOnlyTools,
          ),
          tablet: (_) => _buildPage(
            context,
            padding: ThemeTokens.paddingTablet,
            sectionGap: ThemeTokens.sectionGapTablet + ThemeTokens.spaceSm,
            commonTools: commonTools,
            userOnlyTools: userOnlyTools,
          ),
          desktop: (_) => _buildPage(
            context,
            padding: ThemeTokens.paddingDesktop,
            sectionGap: ThemeTokens.sectionGapDesktop + ThemeTokens.spaceSm,
            commonTools: commonTools,
            userOnlyTools: userOnlyTools,
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required double padding,
    required double sectionGap,
    required List<McpTool> commonTools,
    required List<McpTool> userOnlyTools,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(
            onBack: () => context.go(Routes.home),
            commonCount: commonTools.length,
            userOnlyCount: userOnlyTools.length,
            documentCount: _documents.length,
            isBusy: _isBusy,
            onRefreshDocuments: () => _runAction(
              () async => _loadDocuments(),
              successMessage: 'Đã làm mới danh sách tài liệu.',
            ),
          ),
          SizedBox(height: sectionGap),
          _SectionCard(
            title: 'Kho dữ liệu cho Agent',
            subtitle:
                'Tải dữ liệu vào bộ nhớ cục bộ. Agent có thể gọi công cụ '
                '`self.knowledge.search` để tìm và đọc thông tin.',
            child: _buildKnowledgeSection(context),
          ),
          SizedBox(height: sectionGap),
          _SectionCard(
            title: 'Công cụ chung',
            subtitle: 'AI và người dùng đều có thể gọi.',
            child: _ToolList(
              tools: commonTools,
              audienceLabel: 'AI + người dùng',
            ),
          ),
          SizedBox(height: sectionGap),
          _SectionCard(
            title: 'Công cụ chỉ người dùng',
            subtitle: 'Chỉ người dùng được gọi.',
            child: _ToolList(
              tools: userOnlyTools,
              audienceLabel: 'chỉ người dùng',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeSection(BuildContext context) {
    final mutedStyle = context.theme.typography.sm.copyWith(
      color: context.theme.colors.mutedForeground,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_statusText != null) ...[
          _StatusBox(text: _statusText!, isError: _statusIsError),
          const SizedBox(height: ThemeTokens.spaceMd),
        ],
        Text(
          '1) Tải nội dung trực tiếp',
          style: context.theme.typography.base.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        FTextField(
          label: const Text('Tên tài liệu'),
          minLines: 1,
          maxLines: 1,
          control: FTextFieldControl.lifted(
            value: TextEditingValue(
              text: _textDocName,
              selection: TextSelection.collapsed(offset: _textDocName.length),
            ),
            onChange: (value) {
              setState(() {
                _textDocName = value.text;
              });
            },
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        FTextField(
          label: const Text('Nội dung tài liệu'),
          minLines: 4,
          maxLines: 8,
          control: FTextFieldControl.lifted(
            value: TextEditingValue(
              text: _textDocContent,
              selection: TextSelection.collapsed(
                offset: _textDocContent.length,
              ),
            ),
            onChange: (value) {
              setState(() {
                _textDocContent = value.text;
              });
            },
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        FButton(
          onPress: _isBusy ? null : _handleUploadText,
          child: _isBusy
              ? const FCircularProgress()
              : const Text('Tải nội dung lên'),
        ),
        const SizedBox(height: ThemeTokens.spaceLg),
        Text(
          '2) Tải từ đường dẫn file',
          style: context.theme.typography.base.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        FTextField(
          label: const Text('Đường dẫn file'),
          minLines: 1,
          maxLines: 2,
          control: FTextFieldControl.lifted(
            value: TextEditingValue(
              text: _filePath,
              selection: TextSelection.collapsed(offset: _filePath.length),
            ),
            onChange: (value) {
              setState(() {
                _filePath = value.text;
              });
            },
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        FTextField(
          label: const Text('Tên hiển thị (tuỳ chọn)'),
          minLines: 1,
          maxLines: 1,
          control: FTextFieldControl.lifted(
            value: TextEditingValue(
              text: _fileAlias,
              selection: TextSelection.collapsed(offset: _fileAlias.length),
            ),
            onChange: (value) {
              setState(() {
                _fileAlias = value.text;
              });
            },
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        FButton(
          onPress: _isBusy ? null : _handleUploadFile,
          child: _isBusy
              ? const FCircularProgress()
              : const Text('Tải file lên'),
        ),
        const SizedBox(height: ThemeTokens.spaceXs),
        Text(
          'Gợi ý: dùng file văn bản UTF-8 (`.txt`, `.md`, `.json`) để dễ tìm kiếm.',
          style: mutedStyle,
        ),
        const SizedBox(height: ThemeTokens.spaceLg),
        Text(
          '3) Tìm thử dữ liệu đã tải',
          style: context.theme.typography.base.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        FTextField(
          label: const Text('Nội dung cần tìm'),
          minLines: 1,
          maxLines: 2,
          control: FTextFieldControl.lifted(
            value: TextEditingValue(
              text: _query,
              selection: TextSelection.collapsed(offset: _query.length),
            ),
            onChange: (value) {
              setState(() {
                _query = value.text;
              });
            },
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        Wrap(
          spacing: ThemeTokens.spaceSm,
          runSpacing: ThemeTokens.spaceSm,
          children: [
            FButton(
              onPress: _isBusy ? null : _handleSearch,
              child: _isBusy
                  ? const FCircularProgress()
                  : const Text('Tìm trong kho dữ liệu'),
            ),
            FButton(
              onPress: _isBusy ? null : _handleClearDocuments,
              style: FButtonStyle.secondary(),
              child: const Text('Xoá toàn bộ tài liệu'),
            ),
          ],
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: ThemeTokens.spaceMd),
          _SearchResults(results: _searchResults),
        ] else if (_searchAttempted) ...[
          const SizedBox(height: ThemeTokens.spaceMd),
          _EmptySearchResult(query: _query),
        ],
        const SizedBox(height: ThemeTokens.spaceLg),
        Text(
          'Tài liệu hiện có (${_documents.length})',
          style: context.theme.typography.base.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        _DocumentList(documents: _documents),
        const SizedBox(height: ThemeTokens.spaceLg),
        Text(
          'Cách dùng với Agent',
          style: context.theme.typography.base.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceXs),
        Text(
          'Sau khi tải dữ liệu, bạn có thể hỏi bình thường. Agent sẽ gọi '
          '`self.knowledge.search` để lấy đoạn phù hợp và trả lời dựa trên đó.',
          style: mutedStyle,
        ),
      ],
    );
  }

  Future<void> _handleUploadText() async {
    final name = _textDocName.trim();
    final content = _textDocContent.trim();
    if (name.isEmpty || content.isEmpty) {
      _setStatus('Cần nhập đầy đủ tên tài liệu và nội dung.', isError: true);
      return;
    }
    await _runAction(() async {
      await _callTool(
        name: 'self.knowledge.upload_text',
        arguments: <String, dynamic>{'name': name, 'text': content},
      );
      await _loadDocuments();
      if (!mounted) {
        return;
      }
      setState(() {
        _textDocContent = '';
      });
    }, successMessage: 'Đã tải tài liệu "$name".');
  }

  Future<void> _handleUploadFile() async {
    final path = _filePath.trim();
    final alias = _fileAlias.trim();
    if (path.isEmpty) {
      _setStatus('Cần nhập đường dẫn file.', isError: true);
      return;
    }
    await _runAction(() async {
      await _callTool(
        name: 'self.knowledge.upload_file',
        arguments: <String, dynamic>{'path': path, 'name': alias},
      );
      await _loadDocuments();
    }, successMessage: 'Đã tải file vào kho dữ liệu.');
  }

  Future<void> _handleSearch() async {
    final query = _query.trim();
    if (query.isEmpty) {
      _setStatus('Cần nhập nội dung tìm kiếm.', isError: true);
      return;
    }
    await _runAction(() async {
      final result = await _callTool(
        name: 'self.knowledge.search',
        arguments: <String, dynamic>{'query': query, 'top_k': _topKDefault},
      );
      final payload = _decodeToolPayload(result);
      final rows = _extractRows(payload, key: 'results');
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = rows;
        _searchAttempted = true;
      });
    }, successMessage: 'Đã tìm kiếm dữ liệu.');
  }

  Future<void> _handleClearDocuments() async {
    await _runAction(() async {
      await _callTool(name: 'self.knowledge.clear');
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = <Map<String, dynamic>>[];
        _searchResults = <Map<String, dynamic>>[];
        _searchAttempted = false;
      });
    }, successMessage: 'Đã xoá toàn bộ tài liệu.');
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await action();
      if (successMessage != null && mounted) {
        _setStatus(successMessage, isError: false);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setStatus(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _loadDocuments() async {
    final result = await _callTool(name: 'self.knowledge.list_documents');
    final payload = _decodeToolPayload(result);
    final rows = _extractRows(payload, key: 'documents');
    if (!mounted) {
      return;
    }
    setState(() {
      _documents = rows;
    });
  }

  Future<Map<String, dynamic>> _callTool({
    required String name,
    Map<String, dynamic> arguments = const <String, dynamic>{},
  }) async {
    final response = await _mcpServer.handleMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': _requestId++,
      'method': 'tools/call',
      'params': <String, dynamic>{'name': name, 'arguments': arguments},
    });
    if (response == null) {
      throw Exception('MCP không có phản hồi.');
    }

    final error = response['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        throw Exception(message);
      }
      throw Exception('MCP trả lỗi không xác định.');
    }

    final result = response['result'];
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    throw Exception('MCP trả kết quả không hợp lệ.');
  }

  Object? _decodeToolPayload(Map<String, dynamic> result) {
    final content = result['content'];
    if (content is! List || content.isEmpty) {
      return null;
    }

    for (final item in content) {
      if (item is! Map) {
        continue;
      }
      final text = item['text'];
      if (text is! String) {
        continue;
      }
      final trimmed = text.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return jsonDecode(trimmed);
        } catch (_) {
          return trimmed;
        }
      }
      return trimmed;
    }
    return null;
  }

  List<Map<String, dynamic>> _extractRows(
    Object? payload, {
    required String key,
  }) {
    if (payload is! Map) {
      return <Map<String, dynamic>>[];
    }
    final items = payload[key];
    if (items is! List) {
      return <Map<String, dynamic>>[];
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _setStatus(String message, {required bool isError}) {
    setState(() {
      _statusText = message;
      _statusIsError = isError;
    });
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.onBack,
    required this.commonCount,
    required this.userOnlyCount,
    required this.documentCount,
    required this.isBusy,
    required this.onRefreshDocuments,
  });

  final VoidCallback onBack;
  final int commonCount;
  final int userOnlyCount;
  final int documentCount;
  final bool isBusy;
  final VoidCallback onRefreshDocuments;

  @override
  Widget build(BuildContext context) {
    final brand = context.theme.brand;
    return Container(
      decoration: BoxDecoration(
        color: brand.headerBackground,
        borderRadius: BorderRadius.circular(ThemeTokens.radiusMd),
        border: Border.all(color: context.theme.colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: ThemeTokens.spaceSm,
              runSpacing: ThemeTokens.spaceSm,
              children: [
                FButton.icon(
                  onPress: onBack,
                  style: FButtonStyle.ghost(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FIcons.arrowLeft,
                        size: 16,
                        color: brand.headerForeground,
                      ),
                      const SizedBox(width: ThemeTokens.spaceXs),
                      Text(
                        'Quay lại Home',
                        style: context.theme.typography.sm.copyWith(
                          color: brand.headerForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                FButton(
                  onPress: isBusy ? null : onRefreshDocuments,
                  style: FButtonStyle.ghost(),
                  child: Text(
                    'Làm mới tài liệu',
                    style: context.theme.typography.sm.copyWith(
                      color: brand.headerForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ThemeTokens.spaceSm),
            Text(
              'Trình quản lý MCP',
              style: context.theme.typography.xl.copyWith(
                color: brand.headerForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceXs),
            Text(
              'Quản lý công cụ MCP và kho dữ liệu để Agent tra cứu.',
              style: context.theme.typography.sm.copyWith(
                color: brand.headerForeground.withAlpha(210),
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceSm),
            Wrap(
              spacing: ThemeTokens.spaceSm,
              runSpacing: ThemeTokens.spaceSm,
              children: [
                _Badge(
                  label: 'công cụ chung: $commonCount',
                  accent: true,
                  inverted: true,
                ),
                _Badge(label: 'chỉ người dùng: $userOnlyCount', inverted: true),
                _Badge(label: 'tài liệu: $documentCount', inverted: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
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
            if (subtitle != null) ...[
              const SizedBox(height: ThemeTokens.spaceXs),
              Text(
                subtitle!,
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: ThemeTokens.spaceMd),
            child,
          ],
        ),
      ),
    );
  }
}

class _ToolList extends StatelessWidget {
  const _ToolList({required this.tools, required this.audienceLabel});

  final List<McpTool> tools;
  final String audienceLabel;

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.build_outlined,
            size: ThemeTokens.spaceLg,
            color: context.theme.colors.mutedForeground,
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          Text(
            'Chưa có công cụ.',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: ThemeTokens.spaceXs),
          Text(
            'Hãy kiểm tra cấu hình MCP hoặc khởi động lại ứng dụng.',
            style: context.theme.typography.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (final tool in tools) ...[
          _ToolCard(tool: tool, audienceLabel: audienceLabel),
          if (tool != tools.last) const SizedBox(height: ThemeTokens.spaceMd),
        ],
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool, required this.audienceLabel});

  final McpTool tool;
  final String audienceLabel;

  @override
  Widget build(BuildContext context) {
    final brand = context.theme.brand;
    final usage = _toolUsage(tool);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThemeTokens.spaceSm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSm),
        border: Border.all(color: context.theme.colors.border),
        color: brand.homeSurface,
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
          Wrap(
            spacing: ThemeTokens.spaceSm,
            runSpacing: ThemeTokens.spaceSm,
            children: [
              _Badge(label: audienceLabel),
              const _Badge(label: 'sẵn sàng', accent: true),
            ],
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          Text(tool.description, style: context.theme.typography.sm),
          const SizedBox(height: ThemeTokens.spaceSm),
          Text(
            tool.properties.isEmpty
                ? 'Tham số: không có'
                : 'Tham số: ${tool.properties.map(_propertyLabel).join(', ')}',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          Text(
            'Cách gọi: $usage',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.documents});

  final List<Map<String, dynamic>> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.folder_outlined,
            size: ThemeTokens.spaceLg,
            color: context.theme.colors.mutedForeground,
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          Text(
            'Chưa có tài liệu nào.',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: ThemeTokens.spaceXs),
          Text(
            'Tải lên file hoặc nhập nội dung để bắt đầu.',
            style: context.theme.typography.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (final doc in documents) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ThemeTokens.spaceSm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThemeTokens.radiusSm),
              border: Border.all(color: context.theme.colors.border),
              color: context.theme.colors.muted,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (doc['name'] ?? '').toString(),
                  style: context.theme.typography.base.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ThemeTokens.spaceXs),
                Text(
                  'Ký tự: ${(doc['characters'] ?? 0).toString()}',
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                Text(
                  'Cập nhật: ${(doc['updated_at'] ?? '').toString()}',
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (doc != documents.last)
            const SizedBox(height: ThemeTokens.spaceSm),
        ],
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results});

  final List<Map<String, dynamic>> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kết quả tìm kiếm (${results.length})',
          style: context.theme.typography.base.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        for (final row in results) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ThemeTokens.spaceSm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThemeTokens.radiusSm),
              border: Border.all(color: context.theme.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (row['name'] ?? '').toString(),
                  style: context.theme.typography.base.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ThemeTokens.spaceXs),
                Text(
                  'Điểm: ${(row['score'] ?? '').toString()}',
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: ThemeTokens.spaceXs),
                Text(
                  (row['snippet'] ?? '').toString(),
                  style: context.theme.typography.sm,
                ),
              ],
            ),
          ),
          if (row != results.last) const SizedBox(height: ThemeTokens.spaceSm),
        ],
      ],
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim();
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Không tìm thấy kết quả',
              style: context.theme.typography.base.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceXs),
            Text(
              normalized.isEmpty
                  ? 'Hãy thử tìm với từ khóa cụ thể hơn.'
                  : 'Không có dữ liệu khớp với "$normalized".',
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final foreground = isError
        ? context.theme.colors.destructive
        : context.theme.colors.primary;
    final background = isError
        ? context.theme.colors.destructive.withAlpha(28)
        : context.theme.colors.primary.withAlpha(24);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThemeTokens.spaceSm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSm),
        border: Border.all(color: context.theme.colors.border),
      ),
      child: Text(
        text,
        style: context.theme.typography.sm.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.accent = false,
    this.inverted = false,
  });

  final String label;
  final bool accent;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final brand = context.theme.brand;
    final foreground = inverted
        ? brand.headerForeground
        : (accent
              ? context.theme.colors.primary
              : context.theme.colors.mutedForeground);
    final background = inverted
        ? brand.headerForeground.withAlpha(accent ? 56 : 28)
        : (accent
              ? context.theme.colors.primary.withAlpha(34)
              : context.theme.colors.muted);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ThemeTokens.spaceSm,
        vertical: ThemeTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSm),
        border: Border.all(color: context.theme.colors.border),
      ),
      child: Text(
        label,
        style: context.theme.typography.sm.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
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
  final buffer = StringBuffer('${property.name}:$type');
  if (property.type == McpPropertyType.integer &&
      property.minValue != null &&
      property.maxValue != null) {
    buffer.write('(${property.minValue}-${property.maxValue})');
  }
  if (property.hasDefault) {
    buffer.write('[mặc định=${property.defaultValue}]');
  }
  return buffer.toString();
}

String _toolUsage(McpTool tool) {
  final arguments = <String, Object?>{};
  for (final property in tool.properties) {
    if (property.hasDefault) {
      arguments[property.name] = property.defaultValue;
      continue;
    }
    switch (property.type) {
      case McpPropertyType.boolean:
        arguments[property.name] = false;
        break;
      case McpPropertyType.integer:
        arguments[property.name] = property.minValue ?? 0;
        break;
      case McpPropertyType.string:
        arguments[property.name] = '<text>';
        break;
    }
  }
  return '{"name":"${tool.name}","arguments":${jsonEncode(arguments)}}';
}
