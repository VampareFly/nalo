// 原生相机桥接：在 Flutter 流程中承载双端原生预览，并通过独立通道请求拍照文件。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 管理单个原生相机 Platform View 的就绪、拍照和释放调用。
class NativeCameraController {
  static const MethodChannel _permissionChannel = MethodChannel(
    'nalo/native_camera_permission',
  );
  MethodChannel? _channel;
  bool _ready = false;

  bool get isReady => _ready;

  /// 通过 AVFoundation 查询或请求 iOS 系统相机权限。
  static Future<NativeCameraPermissionStatus> requestIosPermission() async {
    final value = await _permissionChannel.invokeMethod<String>('request');
    return switch (value) {
      'granted' => NativeCameraPermissionStatus.granted,
      'restricted' => NativeCameraPermissionStatus.restricted,
      _ => NativeCameraPermissionStatus.denied,
    };
  }

  /// 绑定原生视图实例，并查询其相机会话是否已经可拍照。
  Future<void> attach(int viewId) async {
    _channel = MethodChannel('nalo/native_camera_$viewId');
    await refreshReady();
  }

  /// 重新读取原生会话状态，供异步启动期间短暂轮询。
  Future<void> refreshReady() async {
    final channel = _channel;
    if (channel == null) return;
    _ready = await channel.invokeMethod<bool>('isReady') ?? false;
  }

  /// 使用原生高质量拍照能力保存临时文件并返回绝对路径。
  Future<String> capture() async {
    final channel = _channel;
    if (channel == null) throw StateError('Native camera is not attached.');
    final path = await channel.invokeMethod<String>('capture');
    if (path == null || path.isEmpty) {
      throw StateError('Native camera did not return a photo path.');
    }
    return path;
  }

  /// 通知原生视图停止相机会话；Platform View 销毁时仍会再次兜底释放。
  Future<void> dispose() async {
    final channel = _channel;
    _channel = null;
    _ready = false;
    try {
      await channel?.invokeMethod<void>('dispose');
    } on PlatformException {
      // 原生视图可能已经随页面销毁，无需阻断 Flutter 页面释放。
    }
  }
}

/// 表示 iOS 原生相机授权查询结果。
enum NativeCameraPermissionStatus { granted, denied, restricted }

/// 根据当前平台创建 AVFoundation 或 CameraX 预览视图。
class NativeCameraView extends StatelessWidget {
  const NativeCameraView({
    required this.controller,
    required this.onReady,
    required this.onError,
    super.key,
  });

  final NativeCameraController controller;
  final VoidCallback onReady;
  final ValueChanged<Object> onError;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'nalo/native_camera_view',
        onPlatformViewCreated: _attach,
      );
    }
    if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'nalo/native_camera_view',
        onPlatformViewCreated: _attach,
      );
    }
    return const ColoredBox(color: Colors.black);
  }

  Future<void> _attach(int viewId) async {
    try {
      await controller.attach(viewId);
      // 首次打开相机可能需要数秒，等待原生会话完成配置后再开放拍照。
      for (var attempt = 0; attempt < 100; attempt++) {
        if (controller.isReady) {
          onReady();
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await controller.refreshReady();
      }
      throw StateError('Native camera initialization timed out.');
    } catch (error) {
      onError(error);
    }
  }
}
