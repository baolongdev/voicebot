abstract class AuthEvent {
  const AuthEvent();
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthEmailChanged extends AuthEvent {
  const AuthEmailChanged(this.email);

  final String email;
}

class AuthPasswordChanged extends AuthEvent {
  const AuthPasswordChanged(this.password);

  final String password;
}

class AuthLoginSubmitted extends AuthEvent {
  const AuthLoginSubmitted();
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
