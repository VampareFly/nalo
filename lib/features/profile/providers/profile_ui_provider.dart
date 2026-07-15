import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ProfileGender { female, male, preferNotToSay }

class ProfileUiState {
  const ProfileUiState({
    this.firstName = '',
    this.lastName = '',
    this.gender,
    this.birthday,
    this.email = '',
    this.notificationsEnabled = false,
    this.testRemindersEnabled = true,
    this.resultRemindersEnabled = true,
    this.isReferralVisible = true,
  });

  final String firstName;
  final String lastName;
  final ProfileGender? gender;
  final DateTime? birthday;
  final String email;
  final bool notificationsEnabled;
  final bool testRemindersEnabled;
  final bool resultRemindersEnabled;
  final bool isReferralVisible;

  String get displayName => [firstName, lastName].where((part) => part.trim().isNotEmpty).join(' ');

  ProfileUiState copyWith({
    String? firstName,
    String? lastName,
    ProfileGender? gender,
    DateTime? birthday,
    String? email,
    bool? notificationsEnabled,
    bool? testRemindersEnabled,
    bool? resultRemindersEnabled,
    bool? isReferralVisible,
  }) {
    return ProfileUiState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      email: email ?? this.email,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      testRemindersEnabled: testRemindersEnabled ?? this.testRemindersEnabled,
      resultRemindersEnabled: resultRemindersEnabled ?? this.resultRemindersEnabled,
      isReferralVisible: isReferralVisible ?? this.isReferralVisible,
    );
  }
}

class ProfileUiNotifier extends Notifier<ProfileUiState> {
  @override
  ProfileUiState build() => const ProfileUiState();

  void setNotificationsEnabled(bool value) {
    state = state.copyWith(notificationsEnabled: value);
  }

  void setTestRemindersEnabled(bool value) {
    state = state.copyWith(testRemindersEnabled: value);
  }

  void setResultRemindersEnabled(bool value) {
    state = state.copyWith(resultRemindersEnabled: value);
  }

  void updateProfile({
    required String firstName,
    required String lastName,
    required ProfileGender gender,
    required DateTime birthday,
    required String email,
  }) {
    state = state.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      gender: gender,
      birthday: birthday,
      email: email.trim(),
    );
  }

  void dismissReferral() {
    state = state.copyWith(isReferralVisible: false);
  }
}

final profileUiProvider = NotifierProvider<ProfileUiNotifier, ProfileUiState>(ProfileUiNotifier.new);
