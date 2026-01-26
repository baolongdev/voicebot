import '../../../../core/errors/failure.dart';
import '../../domain/entities/user_entity.dart';

enum AuthStatus {
  initial,
  checking,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  const AuthState({
    required this.status,
    required this.email,
    required this.password,
    this.user,
    this.failure,
  });

  factory AuthState.initial() {
    return const AuthState(
      status: AuthStatus.initial,
      email: '',
      password: '',
    );
  }

  final AuthStatus status;
  final String email;
  final String password;
  final UserEntity? user;
  final Failure? failure;

  String? get errorMessage => failure?.message;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  bool get isCheckingAuth =>
      status == AuthStatus.initial || status == AuthStatus.checking;

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? password,
    UserEntity? user,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      password: password ?? this.password,
      user: user ?? this.user,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
