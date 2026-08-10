# Nala Flutter 项目说明

## 项目定位

这是一个基于 Flutter 的 Nala App，当前主要包含用户引导、登录注册、测试流程、首页报告、商品展示、通知权限和个人资料等模块。

项目使用 Dart 3.12.2，采用 Flutter 官方推荐的响应式 Widget 架构，并使用 Riverpod 管理状态和依赖注入。

## 启动入口

应用入口为：

```text
lib/main.dart
```

启动时主要完成：

1. 初始化 Flutter Framework。
2. 初始化 Hive。
3. 初始化 Amplitude，并根据当前环境选择 API Key。
4. 通过 Riverpod ProviderScope 注入全局依赖。
5. 启动 `TesterKitApp`。

Amplitude 在应用生命周期中只初始化一次。

## 目录结构

```text
lib/
├── app/
│   ├── app.dart                 应用根 Widget
│   ├── config/                  环境和应用配置
│   ├── router/                  GoRouter 路由
│   └── theme/                   Material 主题
├── core/
│   ├── analytics/               Amplitude 埋点封装
│   ├── database/                数据库初始化
│   ├── device/                  设备 ID 获取
│   ├── logging/                 Logger 配置
│   ├── network/                 Dio 网络依赖
│   └── storage/                 SharedPreferences 等本地存储
├── features/
│   ├── full_tend/               完整趋势
│   ├── home/                    首页和测试报告
│   ├── notifications/           通知权限
│   ├── onboarding/              引导、登录、注册
│   ├── profile/                 用户资料
│   ├── shop/                    商品和测试套装
│   └── test_flow/               测试流程状态
├── l10n/                        国际化资源和生成代码
└── main.dart                   应用入口
```

## 架构约定

业务调用方向保持为：

```text
Widget → ViewModel / Provider → Repository / Service → 外部系统
```

- Widget 负责展示 UI 和转发用户操作。
- ViewModel 负责页面状态和业务流程编排。
- Provider 负责状态管理和依赖注入。
- Repository 负责业务数据访问。
- Service 负责网络、平台能力或第三方 SDK。
- 不在 Widget 中直接请求接口或编写复杂业务逻辑。

## Riverpod 使用方式

项目统一使用 Riverpod。

- 简单依赖使用 `Provider`。
- 页面状态使用 `NotifierProvider` 或已有项目采用的 Provider 类型。
- Widget 中通过 `ref.watch` 监听状态，通过 `ref.read` 执行操作。
- ViewModel / Notifier 中直接使用自身的 `ref`。
- 普通 Dart 类通过构造函数注入依赖，不直接查找全局 Provider。

## 路由

路由集中维护在：

```text
lib/app/router/app_router.dart
```

页面通过静态 `path` 定义路径，例如：

```dart
static const path = '/get-started';
```

页面跳转统一使用项目现有的 GoRouter 方式。

## 环境配置

当前环境在以下文件手动切换：

```text
lib/app/config/app_environment.dart
```

当前支持：

```dart
enum AppEnvironment { test, production }
```

Amplitude API Key 根据 `currentEnvironment` 自动选择：

```text
lib/core/analytics/amplitude_config.dart
```

后续接口环境也计划复用同一套环境枚举，但 API 环境和 Amplitude 项目切换仍应分别维护。

## Amplitude 埋点

统一封装在：

```text
lib/core/analytics/analytics.dart
```

调用流转：

```text
Widget / ViewModel → AnalyticsService → Amplitude SDK
```

事件分为四类定义：

- `AnalyticsEvent`：事件名称。
- `AnalyticsCommonProperty`：自动添加的公共事件属性。
- `AnalyticsEventProperty`：具体事件按需传入的属性。
- `AnalyticsUserProperty`：用户画像属性。

每次事件上报自动添加：

```text
app_environment
device_id
```

设备 ID 从现有 `DeviceIdService` 获取，设备 ID 存储在钥匙串中。

Widget 中可以使用：

```dart
ref.report(AnalyticsEvent.getStartedClicked);
```

ViewModel 或 Notifier 中使用：

```dart
ref.read(analyticsProvider).report(
  AnalyticsEvent.loginCompleted,
);
```

普通 Dart 类通过构造函数注入 `AnalyticsService`。

用户身份生命周期：

```text
登录成功：identifyUser → 设置用户属性 → 上报登录事件
退出登录：上报退出事件 → 业务退出成功 → resetIdentity
注销账号：上报注销请求 → 后端注销成功 → resetIdentity
```

Amplitude 的 `resetIdentity` 会清空 Amplitude `userId` 并生成新的 Amplitude `deviceId`，但不会删除钥匙串中的自有设备 ID。

## 设备 ID

设备 ID 相关代码位于：

```text
lib/core/device/device_id_service.dart
lib/core/device/device_id_provider.dart
```

设备 ID 由原生平台能力获取，并通过 MethodChannel 提供给 Flutter。业务代码不应直接调用 MethodChannel，应使用 `DeviceIdService`。

## 国际化

新增用户可见文案需要放入：

```text
lib/l10n/app_en.arb
lib/l10n/app_zh.arb
```

生成文件位于 `lib/l10n/generated/`，不要手动修改生成文件。

## 日志和错误处理

项目统一使用已有 Logger：

```text
lib/core/logging/logger_provider.dart
```

不要新增 `print`。第三方 SDK 或埋点失败通常只记录日志，不应阻断主要业务流程；登录、支付、账号注销等关键业务仍需由业务层明确处理失败结果。

## 主要依赖

- Flutter / Flutter Localizations
- Riverpod：状态管理和依赖注入
- GoRouter：路由
- Dio：网络请求
- Hive / Drift：本地数据和数据库
- Firebase Core / Crashlytics：崩溃监控
- Amplitude Flutter：产品分析和埋点
- Flutter AppAuth：认证流程
- Logger：日志

具体版本以 `pubspec.yaml` 为准。

## 修改代码时的文档要求

- 新增模块或核心文件时，同步更新本文件的目录和架构说明。
- 修改调用流转、环境切换、埋点身份流程或生命周期时，同步更新对应章节。
- 新增公开类、枚举、Provider、Service 或方法时，添加简短中文注释。
- 代码实现与注释、本文档必须保持一致。
- 本文件描述项目事实和使用方式；开发规范以 `AGENTS.md` 为准。

## 验证约定

除非用户明确要求，不自动执行 Flutter 运行、测试、分析、构建或 Xcode/Gradle 验证。代码修改完成后，交由项目维护者自行运行验证。
