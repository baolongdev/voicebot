import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/forui/theme_tokens.dart';
import '../../presentation/app/update_cubit.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/responsive_builder.dart';
import '../../system/update/github_updater.dart';
import '../../theme/theme_extensions.dart';

class UpdateDownloadPage extends StatefulWidget {
  const UpdateDownloadPage({super.key});

  @override
  State<UpdateDownloadPage> createState() => _UpdateDownloadPageState();
}

class _UpdateDownloadPageState extends State<UpdateDownloadPage> {
  // static const MethodChannel _kioskChannel = MethodChannel('voicebot/kiosk');

  @override
  void initState() {
    super.initState();
    // _exitKioskMode();
    context.read<UpdateCubit>().checkForUpdates();
  }

  // Future<void> _exitKioskMode() async {
  //   try {
  //     await _kioskChannel.invokeMethod<void>('stopLockTask');
  //   } catch (_) {}
  // }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: SafeArea(
        child: ResponsiveBuilder(
          mobile: (_) =>
              _buildPage(context, padding: ThemeTokens.paddingMobile),
          tablet: (_) =>
              _buildPage(context, padding: ThemeTokens.paddingTablet),
          desktop: (_) =>
              _buildPage(context, padding: ThemeTokens.paddingDesktop),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, {required double padding}) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: BlocBuilder<UpdateCubit, UpdateDownloadState>(
        builder: (context, state) {
          final statusText = _statusText(state);
          final progress = state.progress;
          final percent = progress == null
              ? null
              : (progress * 100).clamp(0, 100).floor();
          final sizeText = _formatSize(state.receivedBytes, state.totalBytes);
          final isChecking = state.status == UpdateDownloadStatus.checking;
          final isDownloading =
              state.status == UpdateDownloadStatus.downloading;
          final isFailed = state.status == UpdateDownloadStatus.failed;
          final isCompleted = state.status == UpdateDownloadStatus.completed;
          final isAvailable =
              state.status == UpdateDownloadStatus.updateAvailable;
          final isIdle = state.status == UpdateDownloadStatus.idle;
          final badgeLabel = isCompleted
              ? 'đã tải xong'
              : (isFailed
                    ? 'thất bại'
                    : (isChecking
                          ? 'đang kiểm tra'
                          : (isAvailable
                                ? 'có bản mới'
                                : (isIdle ? 'sẵn sàng' : 'đang cập nhật'))));
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderCard(
                  onBack: () => context.go(Routes.home),
                  badgeLabel: badgeLabel,
                  version: state.latestVersion ?? state.version,
                ),
                const SizedBox(height: ThemeTokens.spaceLg),
                Container(
                  padding: const EdgeInsets.all(ThemeTokens.spaceMd),
                  decoration: BoxDecoration(
                    color: context.theme.colors.background,
                    borderRadius: BorderRadius.circular(ThemeTokens.radiusMd),
                    border: Border.all(color: context.theme.colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: context.theme.typography.sm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isFailed
                              ? context.theme.colors.error
                              : context.theme.colors.foreground,
                        ),
                      ),
                      const SizedBox(height: ThemeTokens.spaceSm),
                      _ReleaseInfo(state: state),
                      if (isChecking || isDownloading)
                        const SizedBox(height: ThemeTokens.spaceSm),
                      if (isChecking)
                        const FCircularProgress()
                      else if (isDownloading && progress != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FDeterminateProgress(
                              value: progress.clamp(0, 1),
                              semanticsLabel: 'Update download progress',
                            ),
                            const SizedBox(height: ThemeTokens.spaceSm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  sizeText,
                                  style: context.theme.typography.xs,
                                ),
                                if (percent != null)
                                  Text(
                                    '$percent%',
                                    style: context.theme.typography.xs.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        )
                      else if (isDownloading)
                        const FCircularProgress(),
                      if (isFailed && state.error != null) ...[
                        const SizedBox(height: ThemeTokens.spaceSm),
                        Text(
                          state.error!,
                          style: context.theme.typography.xs.copyWith(
                            color: context.theme.colors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: ThemeTokens.spaceLg),
                if (isFailed || isCompleted || isIdle || isAvailable)
                  FButton(
                    onPress: () =>
                        context.read<UpdateCubit>().checkForUpdates(),
                    style: FButtonStyle.primary(),
                    child: Text(
                      isCompleted || isAvailable ? 'Kiểm tra lại' : 'Thử lại',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusText(UpdateDownloadState state) {
    switch (state.status) {
      case UpdateDownloadStatus.checking:
        return 'Đang kiểm tra cập nhật...';
      case UpdateDownloadStatus.updateAvailable:
        final version = state.latestVersion?.isNotEmpty == true
            ? 'v${state.latestVersion}'
            : 'mới';
        return 'Có bản cập nhật $version (thiết bị này không cài APK trực tiếp).';
      case UpdateDownloadStatus.downloading:
        final version = state.version?.isNotEmpty == true
            ? 'v${state.version}'
            : '';
        return 'Đang tải bản cập nhật $version';
      case UpdateDownloadStatus.completed:
        return 'Đã tải xong. Đang chuẩn bị cài đặt...';
      case UpdateDownloadStatus.failed:
        return 'Cập nhật thất bại';
      case UpdateDownloadStatus.idle:
        return 'Không có cập nhật mới';
    }
  }

  String _formatSize(int received, int? total) {
    String format(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
    if (total != null && total > 0) {
      return '${format(received)} MB / ${format(total)} MB';
    }
    if (received > 0) {
      return '${format(received)} MB';
    }
    return '';
  }
}

class _ReleaseInfo extends StatelessWidget {
  const _ReleaseInfo({required this.state});

  final UpdateDownloadState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final latestVersion =
        (state.latestVersion ?? state.version ?? '').trim().isEmpty
        ? '-'
        : (state.latestVersion ?? state.version ?? '').trim();
    final versionText = latestVersion == '-' ? '-' : 'v$latestVersion';
    final releaseNotes = (state.releaseNotes ?? '').trim();
    final commitMessage = (state.commitMessage ?? '').trim();
    final releasedAt = _formatReleasedAt(state.releasedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ThemeTokens.spaceMd),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(ThemeTokens.radiusMd),
            border: Border.all(color: colors.primary.withAlpha(90)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phiên bản mới nhất',
                style: context.theme.typography.sm.copyWith(
                  color: colors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: ThemeTokens.spaceXs),
              Text(
                versionText,
                style: context.theme.typography.xl.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        _InfoCard(
          label: 'Ghi chú phát hành',
          value: releaseNotes.isEmpty ? '-' : releaseNotes,
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        _InfoCard(
          label: 'Nội dung cập nhật',
          value: commitMessage.isEmpty ? '-' : commitMessage,
        ),
        const SizedBox(height: ThemeTokens.spaceSm),
        _InfoCard(label: 'Thời gian phát hành', value: releasedAt),
      ],
    );
  }

  String _formatReleasedAt(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return '-';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThemeTokens.spaceSm),
      decoration: BoxDecoration(
        color: context.theme.colors.muted,
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSm),
        border: Border.all(color: context.theme.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.theme.typography.sm.copyWith(
              fontWeight: FontWeight.w600,
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: ThemeTokens.spaceXs),
          SelectableText(
            value,
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.onBack,
    required this.badgeLabel,
    required this.version,
  });

  final VoidCallback onBack;
  final String badgeLabel;
  final String? version;

  @override
  Widget build(BuildContext context) {
    final brand = context.theme.brand;
    final versionLabel = version?.isNotEmpty == true
        ? 'phiên bản: v$version'
        : 'phiên bản: -';

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
            const SizedBox(height: ThemeTokens.spaceSm),
            Text(
              'Cập nhật ứng dụng',
              style: context.theme.typography.xl.copyWith(
                color: brand.headerForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceXs),
            Text(
              'Theo dõi và tải phiên bản mới từ nguồn phát hành.',
              style: context.theme.typography.sm.copyWith(
                color: brand.headerForeground.withAlpha(210),
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceSm),
            Wrap(
              spacing: ThemeTokens.spaceSm,
              runSpacing: ThemeTokens.spaceSm,
              children: [
                _Badge(label: badgeLabel, inverted: true, accent: true),
                _Badge(label: versionLabel, inverted: true),
              ],
            ),
          ],
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
