import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../application/usecases/check_auth.usecase.dart';
import '../../application/usecases/login.usecase.dart';
import '../../application/usecases/logout.usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginUseCase login,
    required LogoutUseCase logout,
    required CheckAuthUseCase checkAuth,
  })  : _login = login,
        _logout = logout,
        _checkAuth = checkAuth,
        super(
          AppConfig.authEnabled
              ? AuthState.initial()
              : AuthState.initial().copyWith(
                  status: AuthStatus.authenticated,
                  user: null,
                  clearFailure: true,
                ),
        ) {
    on<AuthStarted>(_onStarted);
    on<AuthEmailChanged>(_onEmailChanged);
    on<AuthPasswordChanged>(_onPasswordChanged);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final CheckAuthUseCase _checkAuth;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    if (!AppConfig.authEnabled) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: null,
          clearFailure: true,
        ),
      );
      return;
    }
    emit(state.copyWith(status: AuthStatus.checking, clearFailure: true));
    final result = await _checkAuth();
    if (result.isSuccess) {
      final user = result.data;
      if (user == null) {
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            user: null,
            clearFailure: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            clearFailure: true,
          ),
        );
      }
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          failure: result.failure,
        ),
      );
    }
  }

  void _onEmailChanged(AuthEmailChanged event, Emitter<AuthState> emit) {
    if (!AppConfig.authEnabled) {
      return;
    }
    emit(
      state.copyWith(
        email: event.email,
        status: _clearErrorStatus(state.status),
        clearFailure: true,
      ),
    );
  }

  void _onPasswordChanged(AuthPasswordChanged event, Emitter<AuthState> emit) {
    if (!AppConfig.authEnabled) {
      return;
    }
    emit(
      state.copyWith(
        password: event.password,
        status: _clearErrorStatus(state.status),
        clearFailure: true,
      ),
    );
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    if (!AppConfig.authEnabled) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: null,
          clearFailure: true,
        ),
      );
      return;
    }
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    final result = await _login(email: state.email, password: state.password);
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: result.data,
          clearFailure: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          user: null,
          failure: result.failure,
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!AppConfig.authEnabled) {
      return;
    }
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    await _logout();
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        clearFailure: true,
      ),
    );
  }

  AuthStatus _clearErrorStatus(AuthStatus current) {
    if (current == AuthStatus.error) {
      return AuthStatus.unauthenticated;
    }
    return current;
  }
}
