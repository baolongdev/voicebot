import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../core/permissions/permission_type.dart';
import '../../routing/routes.dart';
import '../../system/permissions/permission_notifier.dart';
import '../../system/permissions/permission_state.dart';
import 'v2_permission_sheet_content.dart';

class V2PermissionsPage extends StatefulWidget {
  const V2PermissionsPage({super.key});

  @override
  State<V2PermissionsPage> createState() => _V2PermissionsPageState();
}

class _V2PermissionsPageState extends State<V2PermissionsPage> {
  bool _didSubmit = false;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _openPermissionSheet();
      }
    });
  }

  Future<void> _openPermissionSheet() async {
    if (_sheetOpen) {
      return;
    }
    _sheetOpen = true;
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      useRootNavigator: true,
      useSafeArea: true,
      resizeToAvoidBottomInset: true,
      barrierDismissible: false,
      mainAxisMaxRatio: null,
      draggable: true,
      builder: (context) => V2PermissionSheetContent(
        onAllow: (type) => _requestPermission(context, type),
        onNotNow: () => _handleNotNow(context),
      ),
    ).whenComplete(() {
      _sheetOpen = false;
      if (mounted && !_didSubmit) {
        // Keep showing the sheet unless the user acted.
        _openPermissionSheet();
      }
    });
  }

  Future<void> _requestPermission(
    BuildContext context,
    PermissionType type,
  ) async {
    setState(() {
      _didSubmit = true;
    });
    await context.read<PermissionCubit>().requestPermission(type);
  }

  void _handleNotNow(BuildContext context) {
    setState(() {
      _didSubmit = true;
    });
  }

  void _closeSheetIfOpen() {
    if (_sheetOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PermissionCubit, PermissionState>(
      listenWhen: (_, state) => _didSubmit && !state.isChecking,
      listener: (context, state) {
        if (state.isReady) {
          _closeSheetIfOpen();
          context.go(Routes.v2Home);
        }
      },
      child: const FScaffold(child: SizedBox.expand()),
    );
  }
}
