// 管理注册资料、提交校验和年龄边界，并上报资料请求结果。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/onboarding/repositories/user_profile_repository.dart';

/// Figma 注册资料页支持的生理性别。
enum BiologicalSex { female, male }

/// 注册资料提交后的页面处理结果。
enum AccountProfileSubmitResult {
  missingFields,
  under18,
  submissionFailed,
  completed,
}

/// 注册资料页面状态。
class AccountProfileState {
  const AccountProfileState({
    this.email = '',
    this.fullName = '',
    this.dateOfBirth,
    this.biologicalSex,
    this.showMissingFieldsError = false,
    this.isSubmitting = false,
    this.submissionError,
  });

  final String email;
  final String fullName;
  final DateTime? dateOfBirth;
  final BiologicalSex? biologicalSex;
  final bool showMissingFieldsError;
  final bool isSubmitting;
  final String? submissionError;

  int? get age {
    final birthday = dateOfBirth;
    if (birthday == null) return null;
    final today = DateTime.now();
    var value = today.year - birthday.year;
    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      value--;
    }
    return value;
  }

  bool get isOver65 => (age ?? 0) > 65;

  AccountProfileState copyWith({
    String? email,
    String? fullName,
    DateTime? dateOfBirth,
    BiologicalSex? biologicalSex,
    bool? showMissingFieldsError,
    bool? isSubmitting,
    String? submissionError,
    bool clearSubmissionError = false,
  }) {
    return AccountProfileState(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      showMissingFieldsError:
          showMissingFieldsError ?? this.showMissingFieldsError,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionError: clearSubmissionError
          ? null
          : submissionError ?? this.submissionError,
    );
  }
}

/// 编排资料输入、年龄判断和创建账号。
class AccountProfileViewModel extends Notifier<AccountProfileState> {
  @override
  AccountProfileState build() => const AccountProfileState();

  /// 初始化 Shopify 服务端返回的只读邮箱。
  void initializeEmail(String email) {
    if (state.email == email) return;
    state = state.copyWith(
      email: email,
      showMissingFieldsError: _shouldKeepMissingFieldsError(email: email),
      clearSubmissionError: true,
    );
  }

  /// 保存完整姓名。
  void updateFullName(String value) {
    state = state.copyWith(
      fullName: value,
      showMissingFieldsError: _shouldKeepMissingFieldsError(fullName: value),
      clearSubmissionError: true,
    );
  }

  /// 保存生日并重新计算年龄提示状态。
  void updateDateOfBirth(DateTime value) {
    state = AccountProfileState(
      email: state.email,
      fullName: state.fullName,
      dateOfBirth: value,
      biologicalSex: state.biologicalSex,
      showMissingFieldsError: _shouldKeepMissingFieldsError(dateOfBirth: value),
      isSubmitting: state.isSubmitting,
      submissionError: null,
    );
  }

  /// 保存生理性别单选结果。
  void selectBiologicalSex(BiologicalSex value) {
    state = state.copyWith(
      biologicalSex: value,
      showMissingFieldsError: _shouldKeepMissingFieldsError(
        biologicalSex: value,
      ),
      clearSubmissionError: true,
    );
  }

  bool _shouldKeepMissingFieldsError({
    String? email,
    String? fullName,
    DateTime? dateOfBirth,
    BiologicalSex? biologicalSex,
  }) {
    if (!state.showMissingFieldsError) return false;
    return (email ?? state.email).trim().isEmpty ||
        (fullName ?? state.fullName).trim().isEmpty ||
        (dateOfBirth ?? state.dateOfBirth) == null ||
        (biologicalSex ?? state.biologicalSex) == null;
  }

  /// 仅在用户点击主按钮时校验并提交资料。
  Future<AccountProfileSubmitResult> submit() async {
    if (state.email.trim().isEmpty ||
        state.fullName.trim().isEmpty ||
        state.dateOfBirth == null ||
        state.biologicalSex == null) {
      state = state.copyWith(showMissingFieldsError: true);
      return AccountProfileSubmitResult.missingFields;
    }
    state = state.copyWith(showMissingFieldsError: false);
    if ((state.age ?? 0) < 18) return AccountProfileSubmitResult.under18;
    if (state.isSubmitting) return AccountProfileSubmitResult.missingFields;
    state = state.copyWith(isSubmitting: true, clearSubmissionError: true);
    final submittedProfile = state;
    try {
      final repository = await ref.read(userProfileRepositoryProvider.future);
      await repository.update(
        fullName: state.fullName,
        birthDay: state.dateOfBirth!,
        gender: state.biologicalSex == BiologicalSex.female ? 1 : 2,
      );
      await _reportRequestResult(submittedProfile, isSuccess: true);
      state = state.copyWith(isSubmitting: false);
      return AccountProfileSubmitResult.completed;
    } on ApiException catch (error) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: '${error.code}: ${error.message}',
      );
      state = state.copyWith(
        isSubmitting: false,
        submissionError: error.message,
      );
      return AccountProfileSubmitResult.submissionFailed;
    } on NetworkException catch (error) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: '${error.type.name}: ${error.message}',
      );
      state = state.copyWith(
        isSubmitting: false,
        submissionError: error.message,
      );
      return AccountProfileSubmitResult.submissionFailed;
    } on SessionExpiredException catch (error) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: 'session_expired: ${error.message}',
      );
      state = state.copyWith(
        isSubmitting: false,
        submissionError: error.message,
      );
      return AccountProfileSubmitResult.submissionFailed;
    } on ResponseFormatException catch (error) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: 'response_format_error: ${error.message}',
      );
      state = state.copyWith(
        isSubmitting: false,
        submissionError: error.message,
      );
      return AccountProfileSubmitResult.submissionFailed;
    } catch (_) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: 'unknown_error: Unable to update user profile',
      );
      state = state.copyWith(
        isSubmitting: false,
        submissionError: 'Unable to update your profile. Please try again.',
      );
      return AccountProfileSubmitResult.submissionFailed;
    }
  }

  Future<void> _reportRequestResult(
    AccountProfileState profile, {
    required bool isSuccess,
    String failReason = '',
  }) {
    final gender = switch (profile.biologicalSex) {
      BiologicalSex.female => AnalyticsGender.female,
      BiologicalSex.male => AnalyticsGender.male,
      null => null,
    };
    return ref
        .read(analyticsProvider)
        .report(
          AnalyticsEvent.createAccountRequestResult,
          properties: {
            ...createAccountAnalyticsProperties(
              email: profile.email,
              name: profile.fullName,
              birth: profile.dateOfBirth,
              gender: gender,
            ),
            AnalyticsEventProperty.isSuccess: isSuccess ? 1 : 0,
            AnalyticsEventProperty.failReason: failReason,
          },
        );
  }
}

/// 提供注册资料页 ViewModel。
final accountProfileViewModelProvider =
    NotifierProvider.autoDispose<AccountProfileViewModel, AccountProfileState>(
      AccountProfileViewModel.new,
    );
