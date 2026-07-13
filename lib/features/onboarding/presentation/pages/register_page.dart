import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tester_kit/features/home/presentation/pages/home_page.dart';
import 'package:tester_kit/features/onboarding/presentation/widgets/onboarding_button.dart';
import 'package:tester_kit/features/onboarding/view_models/register_view_model.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  static const path = '/register';

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthdayController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    _dismissKeyboard();
    final message = await ref.read(registerViewModelProvider.notifier).register(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      birthday: ref.read(registerViewModelProvider).birthday,
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (message != null) {
      // TODO: <pf> Replace the toast when registration error handling is implemented.
      BotToast.showText(text: message, align: Alignment.center);
      return;
    }
    context.go(HomePage.path);
  }

  void _dismissKeyboard([String? _]) {
    FocusScope.of(context).unfocus();
  }

  Future<void> _selectBirthday() async {
    _dismissKeyboard();
    final now = DateTime.now();
    final currentBirthday = ref.read(registerViewModelProvider).birthday;
    final selectedBirthday = await showDatePicker(
      context: context,
      locale: const Locale('en'),
      initialDate: currentBirthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 120, now.month, now.day),
      lastDate: now,
    );

    if (selectedBirthday == null || !mounted) return;
    ref.read(registerViewModelProvider.notifier).setBirthday(selectedBirthday);
    _birthdayController.text = DateFormat.yMMMd('en').format(selectedBirthday);
  }

  @override
  Widget build(BuildContext context) {
    final isPasswordObscured = ref.watch(
      registerViewModelProvider.select((state) => state.isPasswordObscured),
    );

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
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 68),
                  child: IntrinsicHeight(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About you',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 40,
                          fontStyle: FontStyle.italic,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Helps us personalize your insights. Nothing is shared.',
                        style: TextStyle(
                          color: Color(0xFF717277),
                          fontSize: 17,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 34),
                      _RegisterField(
                        label: 'First name',
                        placeholder: 'John',
                        controller: _firstNameController,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: _dismissKeyboard,
                      ),
                      const SizedBox(height: 22),
                      _RegisterField(
                        label: 'Last name',
                        placeholder: 'Smith',
                        controller: _lastNameController,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: _dismissKeyboard,
                      ),
                      const SizedBox(height: 22),
                      _RegisterField(
                        label: 'Birthday',
                        placeholder: 'Select your birthday',
                        controller: _birthdayController,
                        readOnly: true,
                        onTap: _selectBirthday,
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          color: Color(0xFF717277),
                          size: 21,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _RegisterField(
                        label: 'Enter email address',
                        placeholder: 'john.smith@example.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: _dismissKeyboard,
                      ),
                      const SizedBox(height: 22),
                      _RegisterField(
                        label: 'Create a password',
                        placeholder: '........',
                        controller: _passwordController,
                        obscureText: isPasswordObscured,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: _dismissKeyboard,
                        suffixIcon: IconButton(
                          tooltip: isPasswordObscured
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: ref
                              .read(registerViewModelProvider.notifier)
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
                      OnboardingButton(label: 'Register', onPressed: _register),
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

class _RegisterField extends StatelessWidget {
  const _RegisterField({
    required this.label,
    required this.placeholder,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.readOnly = false,
    this.autofillHints,
    this.onTap,
    this.onSubmitted,
    this.suffixIcon,
  });

  final String label;
  final String placeholder;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool readOnly;
  final Iterable<String>? autofillHints;
  final VoidCallback? onTap;
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
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          readOnly: readOnly,
          onTap: onTap,
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
