import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_bloc.dart';
import 'auth_state.dart';

class AuthStateListenable extends ChangeNotifier {
  AuthStateListenable(this._bloc) {
    _subscription = _bloc.stream.listen((_) => notifyListeners());
  }

  final AuthBloc _bloc;
  late final StreamSubscription<AuthState> _subscription;

  bool get isAuthenticated => _bloc.state.isAuthenticated;

  bool get isCheckingAuth => _bloc.state.isCheckingAuth;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
