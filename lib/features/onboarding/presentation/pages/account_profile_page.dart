// 新用户第三方授权后的资料补充页，按登录来源控制 Email编辑能力。
// 页面上报按钮与弹窗行为；校验、年龄边界和请求结果由 ViewModel 管理。

import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nalo/app/navigation/initial_page_ready_provider.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/widgets/nalo_back_button.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';
import 'package:nalo/features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/onboarding/view_models/account_profile_view_model.dart';
import 'package:nalo/features/shop/providers/pending_kit_purchase_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 收集新用户资料并处理未成年与高龄边界。
class AccountProfilePage extends ConsumerStatefulWidget {
  const AccountProfilePage({
    required this.email,
    required this.userId,
    this.loginProvider,
    this.completionDestination = OnboardingCompletionDestination.home,
    super.key,
  });

  static const path = '/account-profile';

  final String email;
  final int userId;
  final LoginProvider? loginProvider;

  /// 资料和 Welcome 流程完成后的最终页面。
  final OnboardingCompletionDestination completionDestination;

  /// 构造包含服务端 Email和登录来源的页面地址。
  static String location(
    String email,
    int userId, [
    OnboardingCompletionDestination completionDestination =
        OnboardingCompletionDestination.home,
    LoginProvider? loginProvider,
  ]) => Uri(
    path: path,
    queryParameters: {
      'email': email,
      'userId': userId.toString(),
      if (loginProvider != null) 'loginProvider': loginProvider.value,
      if (completionDestination == OnboardingCompletionDestination.shop)
        'destination': 'shop',
    },
  ).toString();

  @override
  ConsumerState<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends ConsumerState<AccountProfilePage> {
  static const _under18Title = 'Under 18';
  static const _under18Description =
      'Nalo is designed for adults 18 and over. Please check with a healthcare provider before testing.';
  static const _over65Description =
      'You are over 65. We recommend speaking with your doctor before testing. You can still continue.';

  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _over65ViewReported = false;
  bool _ownsLoadingToast = false;

  /// 协议地址确认前提示 Privacy Policy 暂不可打开。
  void _openPrivacyPolicy() {
    // TODO: <pf> 接入正式 Privacy Policy 链接并使用外部浏览器打开。
    BotToast.showText(text: 'Privacy Policy is not available yet.');
  }

  /// 协议地址确认前提示 Terms 暂不可打开。
  void _openTerms() {
    // TODO: <pf> 接入正式 Terms 链接并使用外部浏览器打开。
    BotToast.showText(text: 'Terms are not available yet.');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(initialPageReadyProvider.notifier).markReady();
    });
    Future.microtask(() {
      _emailController.text = widget.email;
      ref
          .read(accountProfileViewModelProvider.notifier)
          .initializeIdentity(widget.email, widget.loginProvider);
    });
  }

  @override
  void dispose() {
    if (_ownsLoadingToast) EasyLoading.dismiss();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
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
      unawaited(
        ref.report(
          AnalyticsEvent.accountProfileBirthClick,
          properties: {
            AnalyticsEventProperty.pageName:
                AnalyticsPageName.createAccount.value,
            AnalyticsEventProperty.formType:
                AnalyticsProfileFormType.register.value,
            AnalyticsEventProperty.birth: analyticsBirthValue(value),
          },
        ),
      );
    }
  }

  void _selectGender(BiologicalSex value) {
    ref
        .read(accountProfileViewModelProvider.notifier)
        .selectBiologicalSex(value);
    unawaited(
      ref.report(
        AnalyticsEvent.accountProfileGenderClick,
        properties: {
          AnalyticsEventProperty.pageName:
              AnalyticsPageName.createAccount.value,
          AnalyticsEventProperty.formType:
              AnalyticsProfileFormType.register.value,
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
          AnalyticsEventProperty.pageName:
              AnalyticsPageName.createAccount.value,
          AnalyticsEventProperty.formType:
              AnalyticsProfileFormType.register.value,
          AnalyticsEventProperty.desc: _over65Description,
        },
      ),
    );
  }

  void _dismissKeyboard() {
    _emailFocusNode.unfocus();
    _nameFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final state = ref.read(accountProfileViewModelProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.createAccountClick,
        properties: {
          AnalyticsEventProperty.pageName:
              AnalyticsPageName.createAccount.value,
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
        .read(accountProfileViewModelProvider.notifier)
        .submit();
    if (!mounted) return;
    switch (result) {
      case AccountProfileSubmitResult.missingFields:
        return;
      case AccountProfileSubmitResult.under18:
        await _showUnderageDialog();
        return;
      case AccountProfileSubmitResult.over65ConfirmationRequired:
        return;
      case AccountProfileSubmitResult.submissionFailed:
        return;
      case AccountProfileSubmitResult.completed:
        final hasPendingPurchase =
            ref.read(pendingKitPurchaseProvider) != null;
        if (hasPendingPurchase) EasyLoading.show();
        final purchaseResult = hasPendingPurchase
            ? await ref
                  .read(pendingKitPurchaseProvider.notifier)
                  .createPurchaseLink()
            : null;
        if (hasPendingPurchase) EasyLoading.dismiss();
        if (!mounted) return;
        context.go(
          OnboardingWelcomePage.location(
            _nameController.text.trim(),
            widget.userId,
            widget.completionDestination,
          ),
        );
        final uri = purchaseResult?.url;
        if (uri == null) {
          final message = purchaseResult?.errorMessage;
          if (message != null) {
            BotToast.showText(text: message, align: Alignment.center);
          }
          return;
        }
        final didOpen = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!didOpen) {
          BotToast.showText(
            text: 'Unable to open the shop.',
            align: Alignment.center,
          );
        }
        return;
    }
  }

  Future<void> _showUnderageDialog() async {
    await ref.report(
      AnalyticsEvent.under18AlertView,
      properties: const {
        AnalyticsEventProperty.pageName: 'create_account',
        AnalyticsEventProperty.title: _under18Title,
        AnalyticsEventProperty.desc: _under18Description,
      },
    );
    if (!mounted) return;
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
                      properties: const {
                        AnalyticsEventProperty.pageName: 'create_account',
                      },
                    ),
                  );
                  Navigator.of(context).pop();
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
    final state = ref.watch(accountProfileViewModelProvider);
    ref.listen(
      accountProfileViewModelProvider.select((value) => value.isSubmitting),
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
                Transform.translate(
                  offset: const Offset(-10, 0),
                  child: NaloBackButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AuthEntryPage.path);
                            }
                          },
                  ),
                ),
                const SizedBox(height: 12),
                Image.asset(
                  'assets/images/nalo_wordmark_blue.png',
                  width: 92,
                  height: 22,
                  fit: BoxFit.contain,
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
                if (state.requiresAgeConfirmation) ...[
                  VisibilityDetector(
                    key: const ValueKey('register-over-65-notice'),
                    onVisibilityChanged: (info) =>
                        _reportOver65View(info.visibleFraction),
                    child: const _NoticeBox(
                      color: Color(0xFFFDDA7C),
                      icon: Icons.warning_amber_rounded,
                      text: _over65Description,
                      textStyle: TextStyle(
                        color: Color(0xFF1A2433),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
                if (state.showFullNameLengthError) ...[
                  const Text(
                    'Name must be 50 characters or fewer.',
                    style: TextStyle(
                      color: Color(0xFFD4183D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.showEmailFormatError) ...[
                  const Text(
                    'Please enter a valid email address.',
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
                  child: state.canEditEmail
                      ? TextField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          enabled: !state.isSubmitting,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          onChanged: ref
                              .read(accountProfileViewModelProvider.notifier)
                              .updateEmail,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _dismissKeyboard(),
                          decoration: _inputDecoration('Enter email address'),
                        )
                      : _ReadOnlyField(value: state.email, showLock: true),
                ),
                const SizedBox(height: 16),
                _FieldLabel(
                  label: 'Name',
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    enabled: !state.isSubmitting,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (isProfileFullNameTooLong(newValue.text)) {
                          ref
                              .read(accountProfileViewModelProvider.notifier)
                              .showFullNameLengthError();
                          return oldValue;
                        }
                        return newValue;
                      }),
                    ],
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
                      showBorder: false,
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
                      state.requiresAgeConfirmation
                          ? 'Continue anyway'
                          : 'Create account',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'By continuing you agree to our '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: _openPrivacyPolicy,
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                color: Color(0xFF9FA89E),
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF008BC7),
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' and '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: _openTerms,
                            child: const Text(
                              'Terms',
                              style: TextStyle(
                                color: Color(0xFF9FA89E),
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF008BC7),
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF9FA89E),
                      fontSize: 12,
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
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0x801A2433)),
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
  const _ReadOnlyField({
    required this.value,
    this.hint,
    this.icon,
    this.showLock = false,
    this.showBorder = true,
  });
  final String value;
  final String? hint;
  final IconData? icon;
  final bool showLock;
  final bool showBorder;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: !showBorder || value.isEmpty
          ? Colors.white
          : const Color(0xFFF5F2EE),
      borderRadius: BorderRadius.circular(16),
      border: showBorder
          ? Border.all(color: const Color(0x22008BC7))
          : null,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            value.isEmpty ? hint ?? '' : value,
            style: TextStyle(
              color: value.isEmpty
                  ? const Color(0x801A2433)
                  : const Color(0xFF1A2433),
              fontSize: 16,
            ),
          ),
        ),
        if (showLock)
          Image.asset(
            'assets/icons/email_locked.png',
            width: 14,
            height: 14,
            fit: BoxFit.contain,
          )
        else if (icon != null)
          Icon(icon, size: 18, color: const Color(0xFF008BC7)),
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
    this.textStyle,
  });
  final Color color;
  final IconData? icon;
  final String? assetPath;
  final TextStyle? textStyle;
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
            style: textStyle ?? const TextStyle(
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
