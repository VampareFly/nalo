import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/app/config/app_config_provider.dart';
import 'package:tester_kit/core/network/api_client.dart';
import 'package:tester_kit/features/auth/auth_repository.dart';
import 'package:tester_kit/features/auth/auth_session_provider.dart';

/// 管理普通登录页面的表单状态和登录流程。
final loginViewModelProvider =
    NotifierProvider.autoDispose<LoginViewModel, LoginState>(
      LoginViewModel.new,
    );

/// 普通登录页面状态。
class LoginState {
  const LoginState({this.isPasswordObscured = true, this.isLoading = false});

  final bool isPasswordObscured;
  final bool isLoading;

  LoginState copyWith({bool? isPasswordObscured, bool? isLoading}) {
    return LoginState(
      isPasswordObscured: isPasswordObscured ?? this.isPasswordObscured,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 处理登录表单校验和登录结果。
class LoginViewModel extends Notifier<LoginState> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  LoginState build() => const LoginState();

  /// 切换密码明文和密文显示状态。
  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordObscured: !state.isPasswordObscured);
  }

  /// 校验登录表单并执行登录流程。
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    if (state.isLoading) return null;
    if (email.trim().isEmpty) return 'Please enter your email address';
    if (!_emailPattern.hasMatch(email.trim())) {
      return 'Please enter a valid email address';
    }
    if (password.isEmpty) return 'Please enter your password';
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    state = state.copyWith(isLoading: true);
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      final token = await repository.login(
        email: email.trim(),
        password: password,
      );
      ref.read(authSessionProvider.notifier).markAuthenticated(token);
      final appConfig = await ref.read(appConfigRepositoryProvider.future);
      await appConfig.markFirstInstallationCompleted();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } on NetworkException catch (error) {
      return error.message;
    } on ResponseFormatException catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to log in. Please try again.';
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
