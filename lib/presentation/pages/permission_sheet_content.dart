import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:permission_handler/permission_handler.dart' as handler;

import '../../core/permissions/permission_status.dart';
import '../../core/permissions/permission_type.dart';
import '../../core/theme/forui/theme_tokens.dart';
import '../../system/permissions/permission_notifier.dart';
import '../../system/permissions/permission_state.dart';

class PermissionSheetContent extends StatefulWidget {
  const PermissionSheetContent({
    required this.onAllow,
    required this.onNotNow,
    super.key,
  });

  final ValueChanged<PermissionType> onAllow;
  final VoidCallback onNotNow;

  @override
  State<PermissionSheetContent> createState() =>
      _PermissionSheetContentState();
}

class _PermissionSheetContentState extends State<PermissionSheetContent> {
  bool _declined = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<PermissionCubit, PermissionState>(
      builder: (context, state) {
        final orderedPermissions = PermissionState.requiredPermissions;
        final currentPermission =
            _resolveCurrentPermission(orderedPermissions, state);
        final currentMeta = _permissionMeta(currentPermission);
        final currentStatus = state.statuses[currentPermission];
        final showDenied = currentStatus == PermissionStatus.denied ||
            currentStatus == PermissionStatus.permanentlyDenied;
        final permanentlyDenied =
            currentStatus == PermissionStatus.permanentlyDenied;
        final showLaterHint = _declined || showDenied;
        final mediaSize = MediaQuery.sizeOf(context);
        final width = mediaSize.width;
        final shortestSide = mediaSize.shortestSide;
        final maxHeight = mediaSize.height * (width >= 1200 ? 0.5 : 0.6);
        final textScale = shortestSide >= 900
            ? 1.12
            : shortestSide >= 700
                ? 1.06
                : 1.0;
        final titleStyle = textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ).apply(fontSizeFactor: textScale);
        final headingStyle = textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ).apply(fontSizeFactor: textScale);
        final bodyStyle = textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ).apply(fontSizeFactor: textScale);
        final helperStyle = textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ).apply(fontSizeFactor: textScale);
        final errorStyle = textTheme.bodySmall?.copyWith(
          color: colorScheme.error,
        ).apply(fontSizeFactor: textScale);
        final handleColor = colorScheme.onSurfaceVariant.withAlpha(153);

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(ThemeTokens.spaceLg),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ThemeTokens.spaceLg),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ThemeTokens.spaceLg,
                    ThemeTokens.spaceLg,
                    ThemeTokens.spaceLg,
                    ThemeTokens.spaceXl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: handleColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: ThemeTokens.spaceSm),
                      Text(
                        'Quyền ${currentMeta.label}',
                        textAlign: TextAlign.center,
                        style: titleStyle,
                      ),
                      const SizedBox(height: ThemeTokens.spaceLg),
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary.withAlpha(41),
                          ),
                          child: Icon(
                            currentMeta.icon,
                            size: 48,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: ThemeTokens.spaceLg),
                      Text(
                        'Cần quyền ${currentMeta.label.toLowerCase()}',
                        textAlign: TextAlign.center,
                        style: headingStyle,
                      ),
                      const SizedBox(height: ThemeTokens.spaceSm),
                      Text(
                        _permissionDescription(currentPermission),
                        textAlign: TextAlign.center,
                        style: bodyStyle,
                      ),
                      const SizedBox(height: ThemeTokens.spaceMd),
                      if (showDenied) ...[
                        const SizedBox(height: ThemeTokens.spaceMd),
                        Text(
                          'Vui lòng cho phép quyền "${currentMeta.label}".',
                          textAlign: TextAlign.center,
                          style: errorStyle,
                        ),
                      ],
                      const SizedBox(height: ThemeTokens.spaceLg),
                      FButton(
                        onPress: state.isChecking
                            ? null
                            : () => widget.onAllow(currentPermission),
                        child: state.isChecking
                            ? const FCircularProgress()
                            : Text('Cho phép ${currentMeta.label}'),
                      ),
                      if (permanentlyDenied) ...[
                        const SizedBox(height: ThemeTokens.spaceSm),
                        FButton(
                          onPress: handler.openAppSettings,
                          style: FButtonStyle.ghost(),
                          child: const Text('Mở cài đặt'),
                        ),
                      ],
                      const SizedBox(height: ThemeTokens.spaceSm),
                      FButton(
                        onPress: () {
                          setState(() {
                            _declined = true;
                          });
                          widget.onNotNow();
                        },
                        style: FButtonStyle.ghost(),
                        child: const Text('Để sau'),
                      ),
                      if (showLaterHint) ...[
                        const SizedBox(height: ThemeTokens.spaceSm),
                        Text(
                          'Bạn có thể bật lại quyền trong cài đặt hệ thống.',
                          textAlign: TextAlign.center,
                          style: helperStyle,
                        ),
                      ],
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

  PermissionType _resolveCurrentPermission(
    List<PermissionType> ordered,
    PermissionState state,
  ) {
    for (final type in ordered) {
      if (state.statuses[type] != PermissionStatus.granted) {
        return type;
      }
    }
    return ordered.first;
  }

  _PermissionMeta _permissionMeta(PermissionType type) {
    switch (type) {
      case PermissionType.microphone:
        return const _PermissionMeta(
          type: PermissionType.microphone,
          icon: FIcons.mic,
          label: 'Micro',
        );
      case PermissionType.camera:
        return const _PermissionMeta(
          type: PermissionType.camera,
          icon: FIcons.camera,
          label: 'Camera',
        );
      case PermissionType.photos:
        return const _PermissionMeta(
          type: PermissionType.photos,
          icon: FIcons.image,
          label: 'Ảnh',
        );
      case PermissionType.notifications:
        return const _PermissionMeta(
          type: PermissionType.notifications,
          icon: FIcons.bell,
          label: 'Thông báo',
        );
      case PermissionType.bluetooth:
        return const _PermissionMeta(
          type: PermissionType.bluetooth,
          icon: FIcons.bluetooth,
          label: 'Bluetooth',
        );
      case PermissionType.bluetoothScan:
        return const _PermissionMeta(
          type: PermissionType.bluetoothScan,
          icon: FIcons.bluetoothSearching,
          label: 'Bluetooth (quét)',
        );
      case PermissionType.bluetoothConnect:
        return const _PermissionMeta(
          type: PermissionType.bluetoothConnect,
          icon: FIcons.bluetoothConnected,
          label: 'Bluetooth (kết nối)',
        );
      case PermissionType.audio:
        return const _PermissionMeta(
          type: PermissionType.audio,
          icon: FIcons.speaker,
          label: 'Âm thanh',
        );
      case PermissionType.wifi:
        return const _PermissionMeta(
          type: PermissionType.wifi,
          icon: FIcons.wifi,
          label: 'Wi‑Fi',
        );
      case PermissionType.file:
        return const _PermissionMeta(
          type: PermissionType.file,
          icon: FIcons.file,
          label: 'Tệp',
        );
    }
  }

  String _permissionDescription(PermissionType type) {
    switch (type) {
      case PermissionType.microphone:
        return 'Cho phép dùng micro để ghi âm giọng nói và trò chuyện rảnh tay.';
      case PermissionType.camera:
        return 'Cho phép dùng camera để chụp và gửi ảnh trong hội thoại.';
      case PermissionType.photos:
        return 'Cho phép truy cập ảnh để đính kèm và chia sẻ trong chat.';
      case PermissionType.notifications:
        return 'Cho phép thông báo để nhận phản hồi và nhắc nhở kịp thời.';
      case PermissionType.bluetooth:
        return 'Cho phép Bluetooth để kết nối thiết bị và phụ kiện gần bạn.';
      case PermissionType.bluetoothScan:
        return 'Cho phép quét Bluetooth để tìm thiết bị xung quanh.';
      case PermissionType.bluetoothConnect:
        return 'Cho phép kết nối Bluetooth để giao tiếp với thiết bị.';
      case PermissionType.audio:
        return 'Cho phép truy cập âm thanh để phát và xử lý giọng nói.';
      case PermissionType.wifi:
        return 'Cho phép truy cập Wi‑Fi để kết nối mạng ổn định.';
      case PermissionType.file:
        return 'Cho phép truy cập tệp để chia sẻ nội dung trong chat.';
    }
  }
}

class _PermissionMeta {
  const _PermissionMeta({
    required this.type,
    required this.icon,
    required this.label,
  });

  final PermissionType type;
  final IconData icon;
  final String label;
}
