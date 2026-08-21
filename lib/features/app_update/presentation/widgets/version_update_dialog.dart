// 展示通用版本更新弹窗，并根据更新类型控制是否允许稍后处理。
// 页面负责打开外部更新地址，本 Widget 只表达内容和用户操作。

import 'package:flutter/material.dart';
import 'package:nalo/features/app_update/models/app_version_update.dart';

const _blue = Color(0xFF008BC7);
const _ink = Color(0xFF1A2433);
const _muted = Color(0xFF7E897F);
const _yellow = Color(0xFFFDDA7C);

/// Nalo 版本更新弹窗。
class VersionUpdateDialog extends StatelessWidget {
  const VersionUpdateDialog({
    super.key,
    required this.update,
    required this.onUpdatePressed,
    required this.onLaterPressed,
  });

  final AppVersionUpdate update;
  final VoidCallback onUpdatePressed;
  final VoidCallback onLaterPressed;

  @override
  Widget build(BuildContext context) {
    final notes = update.releaseNotes.take(3).toList(growable: false);
    return PopScope(
      canPop: !update.isForceUpdate,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _UpdateLogo(),
                const SizedBox(height: 18),
                const Text(
                  'New version available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Update to v${update.latestVersion} for the latest improvements and a smoother Nalo experience.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final note in notes) _ReleaseNote(note: note),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onUpdatePressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Update now'),
                  ),
                ),
                if (!update.isForceUpdate) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onLaterPressed,
                    style: TextButton.styleFrom(foregroundColor: _muted),
                    child: const Text(
                      'Maybe later',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateLogo extends StatelessWidget {
  const _UpdateLogo();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: _yellow, shape: BoxShape.circle),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/nalo_logo_temp.png',
            fit: BoxFit.contain,
            color: _blue,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

class _ReleaseNote extends StatelessWidget {
  const _ReleaseNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: DecoratedBox(
              decoration: BoxDecoration(color: _blue, shape: BoxShape.circle),
              child: SizedBox(width: 6, height: 6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(color: _ink, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
