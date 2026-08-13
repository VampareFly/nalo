import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nalo/features/profile/presentation/widgets/profile_subpage_widgets.dart';
import 'package:nalo/features/profile/providers/profile_ui_provider.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  static const path = '/profile/edit';

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  DateTime? _birthday;
  ProfileGender? _gender;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileUiProvider);
    _firstNameController = TextEditingController(text: profile.firstName);
    _lastNameController = TextEditingController(text: profile.lastName);
    _emailController = TextEditingController(text: profile.email);
    _birthday = profile.birthday;
    _gender = profile.gender;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('en'),
      initialDate: _birthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 120, now.month, now.day),
      lastDate: now,
    );
    if (selected != null && mounted) setState(() => _birthday = selected);
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_gender == null) {
      BotToast.showText(text: 'Please select your gender', align: Alignment.center);
      return;
    }
    if (_birthday == null) {
      BotToast.showText(text: 'Please select your birthday', align: Alignment.center);
      return;
    }
    ref.read(profileUiProvider.notifier).updateProfile(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      gender: _gender!,
      birthday: _birthday!,
      email: _emailController.text,
    );
    BotToast.showText(text: 'Profile updated', align: Alignment.center);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSubpageScaffold(
      title: 'Edit profile',
      titleFontSize: 40,
      children: [
        const Text(
          'Keep the details used to personalize your health insights up to date.',
          style: TextStyle(color: Color(0xFF717277), fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            children: [
              _ProfileField(label: 'First name', controller: _firstNameController, validator: _required),
              const SizedBox(height: 22),
              _ProfileField(label: 'Last name', controller: _lastNameController, validator: _required),
              const SizedBox(height: 22),
              _LabeledBlock(
                label: 'Gender',
                child: Row(
                  children: [
                    Expanded(
                      child: _GenderChip(label: 'Female', selected: _gender == ProfileGender.female, onPressed: () => _setGender(ProfileGender.female)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GenderChip(label: 'Male', selected: _gender == ProfileGender.male, onPressed: () => _setGender(ProfileGender.male)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _GenderChip(
                        label: 'Prefer not to say',
                        selected: _gender == ProfileGender.preferNotToSay,
                        onPressed: () => _setGender(ProfileGender.preferNotToSay),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _LabeledBlock(
                label: 'Birthday',
                child: _SelectionField(
                  value: _birthday == null ? 'Select your birthday' : DateFormat.yMMMd('en').format(_birthday!),
                  onPressed: _selectBirthday,
                ),
              ),
              const SizedBox(height: 22),
              _ProfileField(
                label: 'Enter email address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF050505),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                child: const Text('Save changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _setGender(ProfileGender gender) => setState(() => _gender = gender);

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim()) ? null : 'Enter a valid email address';
  }
}

class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Color(0xFF66676B), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.controller, this.keyboardType, required this.validator});
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) => _LabeledBlock(
    label: label,
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      autocorrect: false,
      decoration: _fieldDecoration,
    ),
  );
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({required this.value, required this.onPressed});
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(20),
    child: InputDecorator(
      decoration: _fieldDecoration,
      child: Row(
        children: [
          Expanded(child: Text(value, style: TextStyle(color: value.startsWith('Select') ? const Color(0xFF999A9E) : Colors.black))),
          const Icon(Icons.calendar_today_outlined, color: Color(0xFF717277), size: 20),
        ],
      ),
    ),
  );
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({required this.label, required this.selected, required this.onPressed});
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onPressed(),
    showCheckmark: false,
    selectedColor: const Color(0xFF050505),
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFE1E1E1)),
    labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xFF66676B)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );
}

const _fieldDecoration = InputDecoration(
  filled: true,
  fillColor: Colors.white,
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 17),
  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20)), borderSide: BorderSide(color: Color(0xFFE1E1E1))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20)), borderSide: BorderSide(color: Color(0xFFE1E1E1))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20)), borderSide: BorderSide(color: Color(0xFF91A2E4))),
);
