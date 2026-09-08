// 运行环境选择弹窗，由摇一摇入口调用。
import 'package:flutter/material.dart';
import 'package:nalo/app/config/app_environment.dart';
import 'package:nalo/l10n/generated/app_localizations.dart';

/// 展示 Test 与 Production 环境并返回用户选择。
class EnvironmentPickerDialog extends StatelessWidget {
  const EnvironmentPickerDialog({required this.current, super.key});

  final AppEnvironment current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentName = current == AppEnvironment.test
        ? l10n.testEnvironment
        : l10n.productionEnvironment;
    return AlertDialog(
      title: Text(l10n.selectEnvironment),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.currentEnvironment(currentName),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          ...AppEnvironment.values.map(
            (environment) => RadioListTile<AppEnvironment>(
              value: environment,
              groupValue: current,
              title: Text(
                environment == AppEnvironment.test
                    ? l10n.testEnvironment
                    : l10n.productionEnvironment,
              ),
              onChanged: (value) => Navigator.of(context).pop(value),
            ),
          ),
        ],
      ),
    );
  }
}
