// 管理注册资料、基础校验及服务端年龄确认状态，并上报资料请求结果。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/network/api_business_code.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/onboarding/repositories/user_profile_repository.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';

/// Figma 注册资料页支持的生理性别。
enum BiologicalSex { female, male }

/// 注册资料提交后的页面处理结果。
enum AccountProfileSubmitResult {
  missingFields,
  under18,
  over65ConfirmationRequired,
  submissionFailed,
  completed,
}

/// 判断完整姓名是否超过 50 个字符，用于输入限制和提交校验。
bool isProfileFullNameTooLong(String value) => value.runes.length > 50;

/// 判断资料页邮箱是否符合基础地址格式。
bool isProfileEmailValid(String value) => RegExp(
  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
).hasMatch(value.trim());

/// 注册资料页面状态。
class AccountProfileState {
  const AccountProfileState({
    this.email = '',
    this.loginProvider,
    this.fullName = '',
    this.dateOfBirth,
    this.biologicalSex,
    this.showMissingFieldsError = false,
    this.showFullNameLengthError = false,
    this.showEmailFormatError = false,
    this.requiresAgeConfirmation = false,
    this.isSubmitting = false,
    this.submissionError,
  });

  final String email;
  final LoginProvider? loginProvider;
  final String fullName;
  final DateTime? dateOfBirth;
  final BiologicalSex? biologicalSex;
  final bool showMissingFieldsError;
  final bool showFullNameLengthError;
  final bool showEmailFormatError;
  final bool requiresAgeConfirmation;
  final bool isSubmitting;
  final String? submissionError;

  AccountProfileState copyWith({
    String? email,
    LoginProvider? loginProvider,
    String? fullName,
    DateTime? dateOfBirth,
    BiologicalSex? biologicalSex,
    bool? showMissingFieldsError,
    bool? showFullNameLengthError,
    bool? showEmailFormatError,
    bool? requiresAgeConfirmation,
    bool? isSubmitting,
    String? submissionError,
    bool clearSubmissionError = false,
  }) {
    return AccountProfileState(
      email: email ?? this.email,
      loginProvider: loginProvider ?? this.loginProvider,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      showMissingFieldsError:
          showMissingFieldsError ?? this.showMissingFieldsError,
      showFullNameLengthError:
          showFullNameLengthError ?? this.showFullNameLengthError,
      showEmailFormatError:
          showEmailFormatError ?? this.showEmailFormatError,
      requiresAgeConfirmation:
          requiresAgeConfirmation ?? this.requiresAgeConfirmation,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionError: clearSubmissionError
          ? null
          : submissionError ?? this.submissionError,
    );
  }

  /// 除 Shopify 外的登录方式均允许修改联系邮箱。
  bool get canEditEmail => loginProvider != LoginProvider.shopify;
}

/// 编排资料输入、服务端年龄错误码处理和创建账号。
class AccountProfileViewModel extends Notifier<AccountProfileState> {
  @override
  AccountProfileState build() => const AccountProfileState();

  /// 初始化服务端返回的邮箱和登录来源。
  void initializeIdentity(String email, LoginProvider? loginProvider) {
    if (state.email == email && state.loginProvider == loginProvider) return;
    state = state.copyWith(
      email: email,
      loginProvider: loginProvider,
      showMissingFieldsError: _shouldKeepMissingFieldsError(email: email),
      clearSubmissionError: true,
    );
  }

  /// 更新非 Shopify 用户可编辑的联系邮箱。
  void updateEmail(String value) {
    if (!state.canEditEmail) return;
    state = state.copyWith(
      email: value,
      showEmailFormatError: state.showEmailFormatError &&
          value.trim().isNotEmpty &&
          !isProfileEmailValid(value),
      showMissingFieldsError: _shouldKeepMissingFieldsError(email: value),
      clearSubmissionError: true,
    );
  }

  /// 保存完整姓名。
  void updateFullName(String value) {
    state = state.copyWith(
      fullName: value,
      showFullNameLengthError: isProfileFullNameTooLong(value),
      showMissingFieldsError: _shouldKeepMissingFieldsError(fullName: value),
      clearSubmissionError: true,
    );
  }

  /// 用户尝试输入第 51 个字符时展示长度错误。
  void showFullNameLengthError() {
    if (state.showFullNameLengthError) return;
    state = state.copyWith(showFullNameLengthError: true);
  }

  /// 保存生日并清除上一份生日对应的服务端高龄确认状态。
  void updateDateOfBirth(DateTime value) {
    state = AccountProfileState(
      email: state.email,
      loginProvider: state.loginProvider,
      fullName: state.fullName,
      dateOfBirth: value,
      biologicalSex: state.biologicalSex,
      showMissingFieldsError: _shouldKeepMissingFieldsError(dateOfBirth: value),
      showFullNameLengthError: state.showFullNameLengthError,
      showEmailFormatError: state.showEmailFormatError,
      requiresAgeConfirmation: false,
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
    if (isProfileFullNameTooLong(state.fullName)) {
      state = state.copyWith(showFullNameLengthError: true);
      return AccountProfileSubmitResult.missingFields;
    }
    if (state.email.trim().isEmpty ||
        state.fullName.trim().isEmpty ||
        state.dateOfBirth == null ||
        state.biologicalSex == null) {
      state = state.copyWith(showMissingFieldsError: true);
      return AccountProfileSubmitResult.missingFields;
    }
    if (!isProfileEmailValid(state.email)) {
      state = state.copyWith(showEmailFormatError: true);
      return AccountProfileSubmitResult.missingFields;
    }
    state = state.copyWith(
      showMissingFieldsError: false,
      showFullNameLengthError: false,
      showEmailFormatError: false,
    );
    if (state.isSubmitting) return AccountProfileSubmitResult.missingFields;
    state = state.copyWith(isSubmitting: true, clearSubmissionError: true);
    final submittedProfile = state;
    try {
      final repository = await ref.read(userProfileRepositoryProvider.future);
      await repository.update(
        fullName: state.fullName,
        birthDay: state.dateOfBirth!,
        gender: state.biologicalSex == BiologicalSex.male ? 1 : 2,
        email: state.canEditEmail ? state.email.trim() : null,
        ageConfirmed: state.requiresAgeConfirmation,
      );
      await _reportRequestResult(submittedProfile, isSuccess: true);
      state = state.copyWith(
        isSubmitting: false,
        requiresAgeConfirmation: false,
      );
      return AccountProfileSubmitResult.completed;
    } on ApiException catch (error) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: '${error.code}: ${error.message}',
      );
      if (error.code == ApiBusinessCode.ageUnder18) {
        state = state.copyWith(
          isSubmitting: false,
          requiresAgeConfirmation: false,
          clearSubmissionError: true,
        );
        return AccountProfileSubmitResult.under18;
      }
      if (error.code == ApiBusinessCode.ageOver65ConfirmationRequired) {
        state = state.copyWith(
          isSubmitting: false,
          requiresAgeConfirmation: true,
          clearSubmissionError: true,
        );
        return AccountProfileSubmitResult.over65ConfirmationRequired;
      }
      state = state.copyWith(
        isSubmitting: false,
        requiresAgeConfirmation: false,
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
            AnalyticsEventProperty.pageName:
                AnalyticsPageName.createAccount.value,
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
