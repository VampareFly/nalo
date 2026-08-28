# Nalo Flutter 项目说明

## 项目定位

这是一个基于 Flutter 的 Nalo App，当前主要包含用户引导、登录注册、测试流程、首页报告、商品展示、通知权限和个人资料等模块。

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
5. 启动 `NaloApp`。

Amplitude 在应用生命周期中只初始化一次。

Amplitude SDK 日志在 Debug 构建中使用 `LogLevel.debug`，便于从开发控制台观察事件入队和上传；Profile/Release 构建保持 `LogLevel.warn`。`minIdLength` 设置为 `1`，用于支持服务端的短数字用户 ID。

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
│   ├── onboarding/              Shopify 登录注册、资料补充和欢迎流程
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
static const path = '/auth';
```

页面跳转统一使用项目现有的 GoRouter 方式。

当前登录注册流程以 Shopify 认证为统一入口：

```text
AuthEntryPage
→ Nalo 服务端 Shopify 认证
→ AccountProfilePage（新用户）
→ OnboardingWelcomePage
→ HomePage
```

服务端协议联调期间，新入口页保留客户端直连 Shopify 的测试按钮。该按钮不参与正式 Session 和账号创建，后续需要删除。

当前 Profile 流程为：

```text
HomePage
→ ProfilePage（进入时请求 user/info）
→ EditProfilePage（user/update 成功后直接刷新 Profile 快照）
```

Profile 使用 `test_info.sum_count` 展示累计检测数；Email 暂时只读。Notification、Privacy、Terms、Help 和 Shopify Manage 在目标地址确认前只展示临时 Toast。

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

客户端埋点设计、字段和值域以以下文档为准：

```text
docs/requirements/2026-08-20-客户端埋点设计.md
```

页面、业务层和 SDK 的职责分别为：

```text
Widget 上报点击和商品可视曝光
ViewModel 上报请求结果
AnalyticsNavigatorObserver 上报页面曝光
HomePage 上报 Home / Shop Tab 页面访问
AnalyticsService 补充公共属性并调用 Amplitude SDK
```

每次事件上报自动添加：

```text
notification_enabled
platform
app_version
os_version
user_id
kc_id
```

测试和生产数据通过不同 Amplitude API Key 隔离，不额外上报 `app_environment`。`kc_id` 从现有 `DeviceIdService` 获取，并持久化在钥匙串中。

Widget 中可以使用：

```dart
ref.report(
  AnalyticsEvent.loginClick,
  properties: {
    AnalyticsEventProperty.method:
        AnalyticsLoginClickMethod.continueWithShopify.value,
  },
);
```

ViewModel 或 Notifier 中使用：

```dart
ref.read(analyticsProvider).report(
  AnalyticsEvent.loginRequestResult,
  properties: {
    AnalyticsEventProperty.loginMethod: AnalyticsLoginMethod.shopify.value,
    AnalyticsEventProperty.isSuccess: 1,
    AnalyticsEventProperty.failReason: '',
  },
);
```

普通 Dart 类通过构造函数注入 `AnalyticsService`。

Shop 商品卡片使用 `visibility_detector` 判断可视比例：达到 10% 后上报 `sku_view`，每次进入 Shop 或从 Flutter 子页面返回时开启新曝光周期，并按 `product_id + variant_id` 去重；App 前后台切换和外部 Shopify 返回不重置曝光。点击 Get kit 时立即上报 `sku_click`，链接请求和校验完成后由 ViewModel 上报 `shop_shopify_url_request`。

用户身份生命周期：

```text
登录成功：identifyUser → 设置用户属性 → 上报登录事件
退出登录：业务会话清理 → resetIdentity
Token 失效：业务会话清理 → resetIdentity
注销账号：上报注销请求 → 后端注销成功 → resetIdentity
```

Amplitude 的 `resetIdentity` 会清空 Amplitude `userId` 并生成新的 Amplitude `deviceId`，但不会删除钥匙串中的自有设备 ID。

iOS 在登录入口页展示后请求 ATT：授权时将真实 IDFA 写入用户属性 `x-idfa`，拒绝或受限时写入全 0 IDFA；Android 不设置该属性。通知权限状态确定或变化后会同步用户属性 `notification_permission`。

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
- Visibility Detector：商品卡片可视曝光判断
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
