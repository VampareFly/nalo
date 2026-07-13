import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/app/config/app_config_provider.dart';

final registerViewModelProvider =
    NotifierProvider.autoDispose<RegisterViewModel, RegisterState>(
      RegisterViewModel.new,
    );

enum GenderOption { female, male, preferNotToSay }

class RegisterState {
  const RegisterState({
    this.isPasswordObscured = true,
    this.birthday,
    this.gender,
  });

  final bool isPasswordObscured;
  final DateTime? birthday;
  final GenderOption? gender;

  RegisterState copyWith({
    bool? isPasswordObscured,
    DateTime? birthday,
    GenderOption? gender,
  }) {
    return RegisterState(
      isPasswordObscured: isPasswordObscured ?? this.isPasswordObscured,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
    );
  }
}

class RegisterViewModel extends Notifier<RegisterState> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  RegisterState build() => const RegisterState();

  void togglePasswordVisibility() {
    state = state.copyWith(
      isPasswordObscured: !state.isPasswordObscured,
    );
  }

  void setBirthday(DateTime birthday) {
    state = state.copyWith(birthday: birthday);
  }

  void selectGender(GenderOption gender) {
    state = state.copyWith(gender: gender);
  }

  Future<String?> register({
    required String firstName,
    required String lastName,
    required GenderOption? gender,
    required DateTime? birthday,
    required String email,
    required String password,
  }) async {
    if (firstName.trim().isEmpty) return 'Please enter your first name';
    if (lastName.trim().isEmpty) return 'Please enter your last name';
    if (gender == null) return 'Please select your gender';
    if (birthday == null) return 'Please select your birthday';
    if (email.trim().isEmpty) return 'Please enter your email address';
    if (!_emailPattern.hasMatch(email.trim())) {
      return 'Please enter a valid email address';
    }
    if (password.isEmpty) return 'Please create a password';
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // TODO: <pf> Replace the local completion with the real registration request.
    final appConfig = await ref.read(appConfigRepositoryProvider.future);
    await appConfig.markFirstInstallationCompleted();
    return null;
  }
}
