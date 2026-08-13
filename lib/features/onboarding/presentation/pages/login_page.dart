import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/app/config/app_version_provider.dart';
import 'package:tester_kit/features/home/presentation/pages/home_page.dart';
import 'package:tester_kit/features/onboarding/presentation/widgets/onboarding_button.dart';
import 'package:tester_kit/features/onboarding/view_models/login_view_model.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  static const path = '/login';

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _dismissKeyboard([String? _]) {
    FocusScope.of(context).unfocus();
  }

  Future<void> _login() async {
    _dismissKeyboard();
    final message = await ref
        .read(loginViewModelProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    if (message != null) {
      BotToast.showText(text: message, align: Alignment.center);
      return;
    }
    context.go(HomePage.path);
  }

  @override
  Widget build(BuildContext context) {
    final isPasswordObscured = ref.watch(
      loginViewModelProvider.select((state) => state.isPasswordObscured),
    );
    final isLoading = ref.watch(
      loginViewModelProvider.select((state) => state.isLoading),
    );
    final versionLabel = ref.watch(appVersionLabelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F1),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 68,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back.',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 40,
                            fontStyle: FontStyle.italic,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sign in to continue your Nola journey.',
                          style: TextStyle(
                            color: Color(0xFF717277),
                            fontSize: 17,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 34),
                        _LoginField(
                          label: 'Enter email address',
                          placeholder: 'john.smith@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          onSubmitted: _dismissKeyboard,
                        ),
                        const SizedBox(height: 22),
                        _LoginField(
                          label: 'Enter your password',
                          placeholder: '........',
                          controller: _passwordController,
                          obscureText: isPasswordObscured,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: _dismissKeyboard,
                          suffixIcon: IconButton(
                            tooltip: isPasswordObscured
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: ref
                                .read(loginViewModelProvider.notifier)
                                .togglePasswordVisibility,
                            style: IconButton.styleFrom(
                              overlayColor: Colors.transparent,
                            ),
                            icon: Icon(
                              isPasswordObscured
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF717277),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 36),
                        OnboardingButton(
                          label: isLoading ? 'Logging in...' : 'Login',
                          onPressed: isLoading ? null : _login,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: versionLabel.when(
                            data: (label) => Text(
                              label,
                              style: const TextStyle(
                                color: Color(0xFF999A9E),
                                fontSize: 11,
                              ),
                            ),
                            loading: SizedBox.shrink,
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    required this.placeholder,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
    this.onSubmitted,
    this.suffixIcon,
  });

  final String label;
  final String placeholder;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF66676B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: !obscureText,
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF999A9E)),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 20,
            ),
            border: _border,
            enabledBorder: _border,
            focusedBorder: _border,
          ),
        ),
      ],
    );
  }

  static const _border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
    borderSide: BorderSide(color: Color(0xFFE1E1E1)),
  );
}
