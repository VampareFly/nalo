// 管理 Edit profile 的派生初始值、表单校验、年龄边界和更新请求。
// 初始状态直接读取 Profile Provider，页面生命周期不再命令式修改 Provider。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';
import 'package:nalo/features/onboarding/repositories/user_profile_repository.dart';
import 'package:nalo/features/onboarding/view_models/account_profile_view_model.dart';
import 'package:nalo/features/profile/view_models/profile_view_model.dart';

/// 编辑资料提交后的页面处理结果。
enum EditProfileSubmitResult {
  missingFields,
  under18,
  submissionFailed,
  completed,
}

/// Edit profile 页面状态。
class EditProfileState {
  const EditProfileState({
    this.email = '',
    this.fullName = '',
    this.dateOfBirth,
    this.biologicalSex,
    this.showMissingFieldsError = false,
    this.showFullNameLengthError = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.updatedUser,
  });

  final String email;
  final String fullName;
  final DateTime? dateOfBirth;
  final BiologicalSex? biologicalSex;
  final bool showMissingFieldsError;
  final bool showFullNameLengthError;
  final bool isSubmitting;
  final String? errorMessage;
  final AppUserInfo? updatedUser;

  /// 根据完整年月日计算当前周岁。
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

  /// 是否展示超过 65 岁的风险提示和继续按钮。
  bool get isOver65 => (age ?? 0) > 65;

  /// 生成保留未修改字段的新页面状态。
  EditProfileState copyWith({
    String? email,
    String? fullName,
    DateTime? dateOfBirth,
    BiologicalSex? biologicalSex,
    bool? showMissingFieldsError,
    bool? showFullNameLengthError,
    bool? isSubmitting,
    String? errorMessage,
    AppUserInfo? updatedUser,
    bool clearError = false,
  }) => EditProfileState(
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    biologicalSex: biologicalSex ?? this.biologicalSex,
    showMissingFieldsError:
        showMissingFieldsError ?? this.showMissingFieldsError,
    showFullNameLengthError:
        showFullNameLengthError ?? this.showFullNameLengthError,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    updatedUser: updatedUser ?? this.updatedUser,
  );
}

/// 编排编辑资料输入和 user/update 请求。
class EditProfileViewModel extends Notifier<EditProfileState> {
  @override
  EditProfileState build() {
    final user = ref.watch(profileViewModelProvider).user;
    if (user == null) return const EditProfileState();
    return EditProfileState(
      email: user.email?.trim() ?? '',
      fullName: user.fullName?.trim() ?? '',
      dateOfBirth: _parseDate(user.birthDay),
      biologicalSex: switch (user.gender) {
        1 => BiologicalSex.male,
        2 => BiologicalSex.female,
        _ => null,
      },
    );
  }

  /// 更新完整姓名输入。
  void updateFullName(String value) {
    state = state.copyWith(
      fullName: value,
      showFullNameLengthError: isProfileFullNameTooLong(value),
      clearError: true,
    );
  }

  /// 用户尝试输入第 51 个字符时展示长度错误。
  void showFullNameLengthError() {
    if (state.showFullNameLengthError) return;
    state = state.copyWith(showFullNameLengthError: true);
  }

  /// 更新生日并重新计算年龄状态。
  void updateDateOfBirth(DateTime value) {
    state = state.copyWith(dateOfBirth: value, clearError: true);
  }

  /// 更新生理性别单选值。
  void selectBiologicalSex(BiologicalSex value) {
    state = state.copyWith(biologicalSex: value, clearError: true);
  }

  /// 校验年龄和必填项，并提交服务端更新资料。
  Future<EditProfileSubmitResult> submit() async {
    if (isProfileFullNameTooLong(state.fullName)) {
      state = state.copyWith(showFullNameLengthError: true);
      return EditProfileSubmitResult.missingFields;
    }
    if (state.fullName.trim().isEmpty ||
        state.dateOfBirth == null ||
        state.biologicalSex == null) {
      state = state.copyWith(showMissingFieldsError: true);
      return EditProfileSubmitResult.missingFields;
    }
    state = state.copyWith(
      showMissingFieldsError: false,
      showFullNameLengthError: false,
      clearError: true,
    );
    if ((state.age ?? 0) < 18) return EditProfileSubmitResult.under18;
    if (state.isSubmitting) return EditProfileSubmitResult.missingFields;

    state = state.copyWith(isSubmitting: true, clearError: true);
    final submittedProfile = state;
    try {
      final repository = await ref.read(userProfileRepositoryProvider.future);
      final user = await repository.update(
        fullName: state.fullName,
        birthDay: state.dateOfBirth!,
        gender: state.biologicalSex == BiologicalSex.male ? 1 : 2,
      );
      await _reportRequestResult(submittedProfile, isSuccess: true);
      state = state.copyWith(isSubmitting: false, updatedUser: user);
      return EditProfileSubmitResult.completed;
    } on ApiException catch (error) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: '${error.code}: ${error.message}',
      );
      _setFailure(error.message);
    } on SessionExpiredException catch (error) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: 'session_expired: ${error.message}',
      );
      _setFailure(error.message);
    } on NetworkException catch (error) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: '${error.type.name}: ${error.message}',
      );
      _setFailure(error.message);
    } on ResponseFormatException catch (error) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: 'response_format_error: ${error.message}',
      );
      _setFailure(error.message);
    } catch (_) {
      await _reportRequestResult(
        submittedProfile,
        isSuccess: false,
        failReason: 'unknown_error: Unable to update user profile',
      );
      _setFailure('Unable to update your profile. Please try again.');
    }
    return EditProfileSubmitResult.submissionFailed;
  }

  void _setFailure(String message) {
    state = state.copyWith(isSubmitting: false, errorMessage: message);
  }

  Future<void> _reportRequestResult(
    EditProfileState profile, {
    required bool isSuccess,
    String failReason = '',
  }) {
    return ref
        .read(analyticsProvider)
        .report(
          AnalyticsEvent.profileEditRequestResult,
          properties: {
            AnalyticsEventProperty.pageName:
                AnalyticsPageName.profileEdit.value,
            ...createAccountAnalyticsProperties(
              email: profile.email,
              name: profile.fullName,
              birth: profile.dateOfBirth,
              gender: switch (profile.biologicalSex) {
                BiologicalSex.female => AnalyticsGender.female,
                BiologicalSex.male => AnalyticsGender.male,
                null => null,
              },
            ),
            AnalyticsEventProperty.isSuccess: isSuccess ? 1 : 0,
            AnalyticsEventProperty.failReason: failReason,
          },
        );
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

/// 提供随 Edit profile 页面释放的表单状态。
final editProfileViewModelProvider =
    NotifierProvider.autoDispose<EditProfileViewModel, EditProfileState>(
      EditProfileViewModel.new,
    );
