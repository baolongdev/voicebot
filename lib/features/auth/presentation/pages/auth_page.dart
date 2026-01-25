import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/auth_bloc.dart';
import '../state/auth_event.dart';
import '../state/auth_state.dart';
import '../widgets/login_form.dart';
import '../widgets/login_layout.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return LoginLayout(
          formBuilder: (context, metrics) => LoginForm(
            email: state.email,
            password: state.password,
            isLoading: state.status == AuthStatus.loading,
            fieldGap: metrics.fieldGap,
            sectionGap: metrics.sectionGap,
            errorMessage: state.errorMessage,
            onEmailChanged: (value) =>
                context.read<AuthBloc>().add(AuthEmailChanged(value)),
            onPasswordChanged: (value) =>
                context.read<AuthBloc>().add(AuthPasswordChanged(value)),
            onSubmit: () =>
                context.read<AuthBloc>().add(const AuthLoginSubmitted()),
          ),
        );
      },
    );
  }
}
