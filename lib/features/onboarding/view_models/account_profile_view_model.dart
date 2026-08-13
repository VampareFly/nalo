// 管理注册资料、提交校验和年龄边界。

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Figma 注册资料页支持的生理性别。
enum BiologicalSex { female, male }

/// 注册资料提交后的页面处理结果。
enum AccountProfileSubmitResult {
  missingFields,
  under18,
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
  });

  final String email;
  final String fullName;
  final DateTime? dateOfBirth;
  final BiologicalSex? biologicalSex;
  final bool showMissingFieldsError;
  final bool isSubmitting;

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
  }) {
    return AccountProfileState(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      showMissingFieldsError:
          showMissingFieldsError ?? this.showMissingFieldsError,
      isSubmitting: isSubmitting ?? this.isSubmitting,
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
    );
  }

  /// 保存完整姓名。
  void updateFullName(String value) {
    state = state.copyWith(
      fullName: value,
      showMissingFieldsError: _shouldKeepMissingFieldsError(fullName: value),
    );
  }

  /// 保存生日并重新计算年龄提示状态。
  void updateDateOfBirth(DateTime value) {
    state = AccountProfileState(
      email: state.email,
      fullName: state.fullName,
      dateOfBirth: value,
      biologicalSex: state.biologicalSex,
      showMissingFieldsError: _shouldKeepMissingFieldsError(
        dateOfBirth: value,
      ),
    );
  }

  /// 保存生理性别单选结果。
  void selectBiologicalSex(BiologicalSex value) {
    state = state.copyWith(
      biologicalSex: value,
      showMissingFieldsError: _shouldKeepMissingFieldsError(
        biologicalSex: value,
      ),
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
    state = state.copyWith(isSubmitting: true);
    // TODO: <pf> 服务端接口确认后提交授权会话、资料和高龄确认状态。
    state = state.copyWith(isSubmitting: false);
    return AccountProfileSubmitResult.completed;
  }
}

/// 提供注册资料页 ViewModel。
final accountProfileViewModelProvider =
    NotifierProvider.autoDispose<AccountProfileViewModel, AccountProfileState>(
      AccountProfileViewModel.new,
    );
