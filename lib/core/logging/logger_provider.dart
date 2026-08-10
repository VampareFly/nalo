import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// 提供项目统一使用的 Logger。
final loggerProvider = Provider<Logger>((ref) => Logger());
