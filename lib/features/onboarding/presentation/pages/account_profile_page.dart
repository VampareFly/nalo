// 新用户 Shopify 授权后的资料补充页。
// 页面负责输入与反馈，校验、年龄边界和提交状态由 ViewModel 管理。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/onboarding/view_models/account_profile_view_model.dart';

/// 收集新用户资料并处理未成年与高龄边界。
class AccountProfilePage extends ConsumerStatefulWidget {
  const AccountProfilePage({
    required this.email,
    required this.userId,
    this.completionDestination = OnboardingCompletionDestination.home,
    super.key,
  });

  static const path = '/account-profile';

  final String email;
  final int userId;

  /// 资料和 Welcome 流程完成后的最终页面。
  final OnboardingCompletionDestination completionDestination;

  /// 构造包含 Shopify Email 的页面地址。
  static String location(
    String email,
    int userId, [
    OnboardingCompletionDestination completionDestination =
        OnboardingCompletionDestination.home,
  ]) => Uri(
    path: path,
    queryParameters: {
      'email': email,
      'userId': userId.toString(),
      if (completionDestination == OnboardingCompletionDestination.shop)
        'destination': 'shop',
    },
  ).toString();

  @override
  ConsumerState<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends ConsumerState<AccountProfilePage> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(accountProfileViewModelProvider.notifier)
          .initializeEmail(widget.email),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    _dismissKeyboard();
    final now = DateTime.now();
    final state = ref.read(accountProfileViewModelProvider);
    final value = await showDatePicker(
      context: context,
      locale: const Locale('en'),
      initialDate:
          state.dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 120, now.month, now.day),
      lastDate: now,
    );
    if (!mounted) return;
    _dismissKeyboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dismissKeyboard();
    });
    if (value != null) {
      ref
          .read(accountProfileViewModelProvider.notifier)
          .updateDateOfBirth(value);
    }
  }

  void _dismissKeyboard() {
    _nameFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final result = await ref
        .read(accountProfileViewModelProvider.notifier)
        .submit();
    if (!mounted) return;
    switch (result) {
      case AccountProfileSubmitResult.missingFields:
        return;
      case AccountProfileSubmitResult.under18:
        await _showUnderageDialog();
        return;
      case AccountProfileSubmitResult.submissionFailed:
        return;
      case AccountProfileSubmitResult.completed:
        context.go(
          OnboardingWelcomePage.location(
            _nameController.text.trim(),
            widget.userId,
            widget.completionDestination,
          ),
        );
        return;
    }
  }

  Future<void> _showUnderageDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              'Under 18',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nalo is designed for adults 18 and over. Please check with a healthcare provider before testing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9FA89E), height: 1.45),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
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
    final state = ref.watch(accountProfileViewModelProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFEDE8E0),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AuthEntryPage.path);
                          }
                        },
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(overlayColor: Colors.transparent),
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
                      TextSpan(text: 'Create your\n'),
                      TextSpan(
                        text: 'account.',
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
                const SizedBox(height: 24),
                if (state.isOver65) ...[
                  const _NoticeBox(
                    color: Color(0xFFFDDA7C),
                    icon: Icons.warning_amber_rounded,
                    text:
                        'You are over 65. We recommend speaking with your doctor before testing. You can still continue.',
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
                if (state.submissionError != null) ...[
                  Text(
                    state.submissionError!,
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
                const SizedBox(height: 16),
                _FieldLabel(
                  label: 'Name',
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    enabled: !state.isSubmitting,
                    onChanged: ref
                        .read(accountProfileViewModelProvider.notifier)
                        .updateFullName,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
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
                      hint: 'Select your birthday',
                      icon: Icons.calendar_today_outlined,
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
                            : () => ref
                                  .read(
                                    accountProfileViewModelProvider.notifier,
                                  )
                                  .selectBiologicalSex(BiologicalSex.female),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SexButton(
                        label: 'Male',
                        selected: state.biologicalSex == BiologicalSex.male,
                        onTap: state.isSubmitting
                            ? null
                            : () => ref
                                  .read(
                                    accountProfileViewModelProvider.notifier,
                                  )
                                  .selectBiologicalSex(BiologicalSex.male),
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
                      state.isSubmitting
                          ? 'Creating account...'
                          : state.isOver65
                          ? 'Continue anyway'
                          : 'Create account',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'By continuing you agree to our Privacy Policy and Terms.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9FA89E), fontSize: 12),
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
  const _ReadOnlyField({required this.value, this.hint, this.icon});
  final String value;
  final String? hint;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: value.isEmpty ? Colors.white : const Color(0xFFF5F2EE),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x22008BC7)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            value.isEmpty ? hint ?? '' : value,
            style: TextStyle(
              color: value.isEmpty
                  ? const Color(0x881A2433)
                  : const Color(0xFF1A2433),
            ),
          ),
        ),
        if (icon != null) Icon(icon, size: 18, color: const Color(0xFF008BC7)),
      ],
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
  final IconData? icon;
  final String? assetPath;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (assetPath != null)
          Image.asset(assetPath!, width: 20, height: 20)
        else
          Icon(icon, size: 20, color: const Color(0xFF1A2433)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1A2433),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
