import 'dart:async';

import 'package:flutter/foundation.dart';

import 'permission_notifier.dart';
import 'package:voicebot/system/permissions/permission_state.dart';

class PermissionStateListenable extends ChangeNotifier {
  PermissionStateListenable(this._cubit) {
    _subscription = _cubit.stream.listen((_) => notifyListeners());
  }

  final PermissionCubit _cubit;
  late final StreamSubscription<PermissionState> _subscription;

  bool get isChecking => _cubit.state.isChecking;

  bool get isReady => _cubit.state.isReady;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
