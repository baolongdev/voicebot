import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.email,
    required this.password,
    required this.isLoading,
    required this.fieldGap,
    required this.sectionGap,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onSubmit,
    this.errorMessage,
  });

  final String email;
  final String password;
  final bool isLoading;
  final double fieldGap;
  final double sectionGap;
  final String? errorMessage;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          // Allow keyboard submit without requiring pointer interaction.
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
              const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.enter):
              const ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (!isLoading) {
                  onSubmit();
                }
                return null;
              },
            ),
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FocusTraversalOrder(
                order: const NumericFocusOrder(1.0),
                child: Semantics(
                  // Ensure the label is announced even if the control renders
                  // a custom label internally.
                  textField: true,
                  label: 'Email',
                  child: FTextField(
                    label: const Text('Email'),
                    keyboardType: TextInputType.emailAddress,
                    control: FTextFieldControl.lifted(
                      value: TextEditingValue(
                        text: email,
                        selection: TextSelection.collapsed(
                          offset: email.length,
                        ),
                      ),
                      onChange: (value) => onEmailChanged(value.text),
                    ),
                  ),
                ),
              ),
              SizedBox(height: fieldGap),
              FocusTraversalOrder(
                order: const NumericFocusOrder(2.0),
                child: Semantics(
                  textField: true,
                  label: 'Password',
                  child: FTextField(
                    label: const Text('Password'),
                    obscureText: true,
                    control: FTextFieldControl.lifted(
                      value: TextEditingValue(
                        text: password,
                        selection: TextSelection.collapsed(
                          offset: password.length,
                        ),
                      ),
                      onChange: (value) => onPasswordChanged(value.text),
                    ),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                SizedBox(height: fieldGap),
                Semantics(
                  // Announce errors for screen readers without relying on color.
                  liveRegion: true,
                  label: errorMessage!,
                  child: Text(
                    errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              SizedBox(height: sectionGap),
              FocusTraversalOrder(
                order: const NumericFocusOrder(3.0),
                child: FButton(
                  onPress: isLoading ? null : onSubmit,
                  child: isLoading
                      ? Semantics(
                          // Announce progress when submitting.
                          liveRegion: true,
                          label: 'Signing in',
                          child: FCircularProgress(),
                        )
                      : const Text('Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
