import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/app/config/app_config_provider.dart';

final loginViewModelProvider =
    NotifierProvider.autoDispose<LoginViewModel, LoginState>(
      LoginViewModel.new,
    );

class LoginState {
  const LoginState({this.isPasswordObscured = true});

  final bool isPasswordObscured;

  LoginState copyWith({bool? isPasswordObscured}) {
    return LoginState(
      isPasswordObscured: isPasswordObscured ?? this.isPasswordObscured,
    );
  }
}

class LoginViewModel extends Notifier<LoginState> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  LoginState build() => const LoginState();

  void togglePasswordVisibility() {
    state = state.copyWith(
      isPasswordObscured: !state.isPasswordObscured,
    );
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty) return 'Please enter your email address';
    if (!_emailPattern.hasMatch(email.trim())) {
      return 'Please enter a valid email address';
    }
    if (password.isEmpty) return 'Please enter your password';
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // TODO: <pf> Replace the local completion with the real login request.
    final appConfig = await ref.read(appConfigRepositoryProvider.future);
    await appConfig.markFirstInstallationCompleted();
    return null;
  }
}
