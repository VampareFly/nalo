// 按 Figma 展示当前用户资料编辑表单。
// Widget 上报表单交互、提示曝光与保存点击，ViewModel 上报更新请求结果。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/widgets/nalo_back_button.dart';
import 'package:nalo/features/onboarding/view_models/account_profile_view_model.dart';
import 'package:nalo/features/profile/view_models/edit_profile_view_model.dart';
import 'package:nalo/features/profile/view_models/profile_view_model.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 编辑当前登录用户的姓名、生日和生理性别。
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  static const path = '/profile/edit';

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  static const _under18Title = 'Under 18';
  static const _under18Description =
      'Nalo is designed for adults 18 and over. Please check with a healthcare provider before testing.';
  static const _over65Description =
      'You are over 65. We recommend speaking with your doctor before testing. You can still continue.';

  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  bool _over65ViewReported = false;
  bool _suppressSystemBackReport = false;
  bool _ownsLoadingToast = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(profileViewModelProvider).user;
    if (user != null) {
      _nameController.text = user.fullName?.trim() ?? '';
    }
  }

  @override
  void dispose() {
    if (_ownsLoadingToast) {
      EasyLoading.dismiss();
    }
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    _dismissKeyboard();
    final now = DateTime.now();
    final state = ref.read(editProfileViewModelProvider);
    final value = await showDatePicker(
      context: context,
      locale: const Locale('en'),
      initialDate:
          state.dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 120, now.month, now.day),
      lastDate: now,
    );
    if (value != null && mounted) {
      ref.read(editProfileViewModelProvider.notifier).updateDateOfBirth(value);
      unawaited(
        ref.report(
          AnalyticsEvent.accountProfileBirthClick,
          properties: {
            AnalyticsEventProperty.pageName:
                AnalyticsPageName.profileEdit.value,
            AnalyticsEventProperty.formType:
                AnalyticsProfileFormType.editProfile.value,
            AnalyticsEventProperty.birth: analyticsBirthValue(value),
          },
        ),
      );
    }
  }

  void _selectGender(BiologicalSex value) {
    ref.read(editProfileViewModelProvider.notifier).selectBiologicalSex(value);
    unawaited(
      ref.report(
        AnalyticsEvent.accountProfileGenderClick,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.profileEdit.value,
          AnalyticsEventProperty.formType:
              AnalyticsProfileFormType.editProfile.value,
          AnalyticsEventProperty.gender: value == BiologicalSex.female
              ? AnalyticsGender.female.value
              : AnalyticsGender.male.value,
        },
      ),
    );
  }

  void _reportOver65View(double visibleFraction) {
    if (_over65ViewReported || visibleFraction < 0.1) return;
    _over65ViewReported = true;
    unawaited(
      ref.report(
        AnalyticsEvent.accountProfileOver65NoticeView,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.profileEdit.value,
          AnalyticsEventProperty.formType:
              AnalyticsProfileFormType.editProfile.value,
          AnalyticsEventProperty.desc: _over65Description,
        },
      ),
    );
  }

  void _reportBack(String method) {
    unawaited(
      ref.report(
        AnalyticsEvent.profileEditBackClick,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.profileEdit.value,
          AnalyticsEventProperty.method: method,
        },
      ),
    );
  }

  void _handleTopBack() {
    _reportBack('top_back');
    _suppressSystemBackReport = true;
    context.pop();
  }

  void _dismissKeyboard() {
    _nameFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _submit() async {
    _dismissKeyboard();
    final state = ref.read(editProfileViewModelProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.profileEditSaveClick,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.profileEdit.value,
          ...createAccountAnalyticsProperties(
            email: state.email,
            name: state.fullName,
            birth: state.dateOfBirth,
            gender: switch (state.biologicalSex) {
              BiologicalSex.female => AnalyticsGender.female,
              BiologicalSex.male => AnalyticsGender.male,
              null => null,
            },
          ),
        },
      ),
    );
    final result = await ref
        .read(editProfileViewModelProvider.notifier)
        .submit();
    if (!mounted) return;
    switch (result) {
      case EditProfileSubmitResult.missingFields:
      case EditProfileSubmitResult.submissionFailed:
        return;
      case EditProfileSubmitResult.under18:
        await _showUnderageDialog();
        return;
      case EditProfileSubmitResult.completed:
        final user = ref.read(editProfileViewModelProvider).updatedUser;
        if (user != null) {
          ref.read(profileViewModelProvider.notifier).useUpdatedUser(user);
        }
        _suppressSystemBackReport = true;
        context.pop();
        return;
    }
  }

  Future<void> _showUnderageDialog() async {
    await ref.report(
      AnalyticsEvent.under18AlertView,
      properties: {
        AnalyticsEventProperty.pageName: AnalyticsPageName.profileEdit.value,
        AnalyticsEventProperty.title: _under18Title,
        AnalyticsEventProperty.desc: _under18Description,
      },
    );
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFFEF2F2),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD4183D),
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              _under18Title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              _under18Description,
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9FA89E), height: 1.45),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  unawaited(
                    ref.report(
                      AnalyticsEvent.under18AlertGoBackClick,
                      properties: {
                        AnalyticsEventProperty.pageName:
                            AnalyticsPageName.profileEdit.value,
                      },
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008BC7),
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Go back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileViewModelProvider);
    ref.listen(
      editProfileViewModelProvider.select((value) => value.isSubmitting),
      (previous, next) {
        if (next) {
          _ownsLoadingToast = true;
          EasyLoading.show();
        } else if (_ownsLoadingToast) {
          _ownsLoadingToast = false;
          EasyLoading.dismiss();
        }
      },
    );
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_suppressSystemBackReport) {
          _reportBack('system_back');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEDE8E0),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissKeyboard,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(-10, 0),
                    child: NaloBackButton(
                      onPressed: state.isSubmitting ? null : _handleTopBack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'nalo',
                    style: TextStyle(
                      color: Color(0xFF008BC7),
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Edit your\n'),
                        TextSpan(
                          text: 'profile.',
                          style: TextStyle(color: Color(0xFF008BC7)),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      color: Color(0xFF1A2433),
                      fontSize: 30,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (state.isOver65) ...[
                    VisibilityDetector(
                      key: const ValueKey('edit-profile-over-65-notice'),
                      onVisibilityChanged: (info) =>
                          _reportOver65View(info.visibleFraction),
                      child: const _NoticeBox(
                        color: Color(0xFFFDDA7C),
                        icon: Icons.warning_amber_rounded,
                        text: _over65Description,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.showMissingFieldsError) ...[
                    const Text(
                      'Please fill in all fields.',
                      style: TextStyle(
                        color: Color(0xFFD4183D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state.errorMessage != null) ...[
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFD4183D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _FieldLabel(
                    label: 'Email',
                    child: _ReadOnlyField(value: state.email),
                  ),
                  // TODO: <pf> 服务端支持修改 Email 后开放编辑并补充校验。
                  const SizedBox(height: 16),
                  _FieldLabel(
                    label: 'Name',
                    child: TextField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      enabled: !state.isSubmitting,
                      onChanged: ref
                          .read(editProfileViewModelProvider.notifier)
                          .updateFullName,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _dismissKeyboard(),
                      decoration: _inputDecoration('Alex Smith'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel(
                    label: 'Date of birth',
                    child: InkWell(
                      onTap: state.isSubmitting ? null : _pickBirthday,
                      splashFactory: NoSplash.splashFactory,
                      child: _ReadOnlyField(
                        value: state.dateOfBirth == null
                            ? ''
                            : DateFormat.yMMMd('en').format(state.dateOfBirth!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Biological sex',
                    style: TextStyle(
                      color: Color(0xFF1A2433),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _SexButton(
                          label: 'Female',
                          selected: state.biologicalSex == BiologicalSex.female,
                          onTap: state.isSubmitting
                              ? null
                              : () => _selectGender(BiologicalSex.female),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SexButton(
                          label: 'Male',
                          selected: state.biologicalSex == BiologicalSex.male,
                          onTap: state.isSubmitting
                              ? null
                              : () => _selectGender(BiologicalSex.male),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF008BC7),
                        minimumSize: const Size.fromHeight(56),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        state.isOver65 ? 'Continue anyway' : 'Save changes',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _NoticeBox(
                    color: Color(0x11008BC7),
                    assetPath: 'assets/icons/info_blue.png',
                    text:
                        'Your date of birth, biological sex, and personal information are used solely to personalise your hormone reports. They are never sold or shared with third parties.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Colors.black12),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Colors.black12),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Color(0xFF008BC7)),
  ),
);

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1A2433),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 50,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12),
    ),
    child: Text(
      value.isEmpty ? '—' : value,
      style: const TextStyle(color: Color(0xFF1A2433), fontSize: 16),
    ),
  );
}

class _SexButton extends StatelessWidget {
  const _SexButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF008BC7) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF008BC7), width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF008BC7),
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.color,
    required this.text,
    this.icon,
    this.assetPath,
  });

  final Color color;
  final String text;
  final IconData? icon;
  final String? assetPath;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (assetPath != null)
          Image.asset(assetPath!, width: 16, height: 16)
        else
          Icon(icon, size: 20, color: const Color(0xFF1A2433)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF2A6B8A),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );
}
