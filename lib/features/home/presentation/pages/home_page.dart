import 'package:flutter/material.dart';
import 'package:tester_kit/l10n/generated/app_localizations.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const path = '/home';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: SafeArea(
        child: Center(child: Text(l10n.welcomeMessage)),
      ),
    );
  }
}
