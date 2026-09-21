# Nalo Flutter 项目说明

## 基本信息

- 更新日期：2026-09-18
- 当前状态：持续开发和接口联调中
- 技术栈：Flutter、Dart、Riverpod、GoRouter、Dio
- 架构：MVVM，调用方向为 `View → ViewModel/Provider → Repository → Service → 外部系统`
- 测试环境：`https://api-test.naloresults.com`
- 生产环境：`https://api.naloresults.com`

## 项目范围

Nalo App当前包含 Shopify登录注册、Token生命周期、Welcome与通知权限、Home仪表盘、历史记录、Shop、试纸检测、Profile、版本更新、Amplitude埋点和 Crashlytics崩溃收集。

## 启动入口

应用入口为 `lib/main.dart`：

```text
Flutter Binding
→ 系统状态栏配置
→ Debug系统代理初始化
→ Crash Reporting初始化
→ Hive初始化
→ Amplitude初始化
→ ProviderScope
→ NaloApp
```

根 `ProviderScope` 使用统一重试策略。Amplitude只初始化一次，Debug使用详细日志，非 Debug使用警告日志。

## 目录结构

```text
lib/
├── app/                         App、配置、路由和主题
├── core/
│   ├── analytics/               Amplitude埋点
│   ├── crash_reporting/         Crashlytics封装
│   ├── database/                本地数据库初始化
│   ├── device/                  原生设备ID
│   ├── logging/                 Logger
│   ├── network/                 Dio、公共Header、错误码和网络异常
│   ├── sharing/                 系统分享
│   ├── storage/                 基础存储
│   └── widgets/                 跨模块通用Widget
├── features/
│   ├── app_update/              版本检查和更新弹窗
│   ├── auth/                    Nalo Session和Token生命周期
│   ├── home/                    首页、报告和历史记录
│   ├── notifications/           通知权限
│   ├── onboarding/              Shopify认证、资料完善和Welcome
│   ├── profile/                 Profile和资料编辑
│   ├── shop/                    商品和购买链接
│   └── test_flow/               试纸检测流程
├── l10n/                        国际化基础设施
└── main.dart                    应用入口
```

## 架构职责

```text
View
  ↓ 用户操作与状态渲染
ViewModel / Provider
  ↓ 业务编排
Repository
  ↓ 远端数据与本地快照协调
Service
  ↓ HTTP、平台API或第三方SDK
Nalo服务端 / Shopify / 原生平台
```

View不直接请求接口或解析响应；业务状态放在 ViewModel；Repository协调数据；Service处理协议；Provider负责状态和依赖注入。

## 品牌 Logo 使用规则

- 蓝色页面背景使用白色 Logo：`assets/images/nalo_logo_white.png`；登录页和 Welcome 页均如此。
- 其他页面直接使用蓝色 Logo：`assets/images/nalo_logo_blue.png`，默认不额外添加白底，也不把蓝色图形染成其他颜色；版本更新弹窗例外，使用白色圆形底。
- 页面中单独展示的 `nalo` 品牌文字统一使用 Wordmark 图片：蓝色背景使用 `assets/images/nalo_wordmark_white.png`，其他背景使用 `assets/images/nalo_wordmark_blue.png`；普通句子中的 `Nalo` 文案不替换。
- 登录页、欢迎页、检测流程、商品图片占位（包括无图、加载中和加载失败）及版本更新弹窗均遵循以上规则；不要通过图片着色代替对应颜色的资源。
- 只有现有桌面 App Icon 保留白底蓝色图形；iOS、Android 的系统启动页使用独立原生图片，本规则暂不涉及启动页。

## 登录注册流程

```text
AuthEntryPage
→ POST /api/v1/app/auth/shopify/prepare
→ Flutter AppAuth打开 Shopify授权
→ App获得 authorization code和 code_verifier
→ POST /api/v1/app/auth/shopify/exchange
→ 保存 Nalo Token和 User快照
→ 根据 is_profile_completed与 Welcome状态分流
```

登录后分流：

```text
is_profile_completed = 0 → AccountProfilePage
is_profile_completed = 1且Welcome未完成 → OnboardingWelcomePage
is_profile_completed = 1且Welcome已完成 → HomePage
I need a kit → 完成相同资料和Welcome流程后进入Shop Tab
```

`exchange` 直接返回 `data.user` 和 `data.token`，登录成功后不追加请求 `user/info`。

登录页保留客户端直连 Shopify登录/退出测试能力，通过 `_showShopifyTestButtons` 控制，默认关闭。测试 Token只保存在内存，不参与 Nalo Session、分流或账号创建；正式发布前删除。

## Session与本地数据

Token通过 `TokenStorage` 保存，目前使用 SharedPreferences：

```text
auth_access_token
auth_refresh_token
auth_expires_at
```

当前 User快照通过 `CurrentUserStorage` 保存：

```text
key：auth_current_user
内容：id、email、full_name、birth_day、gender、is_profile_completed等字段
```

Welcome状态按 `userId` 独立保存：

- 退出登录或 Session失效：清除 Token和 User快照，保留该用户的 Welcome状态。
- 注销账号：清除 Token、User快照以及该用户的 Welcome状态。
- 卸载重装：本地状态随应用数据清除。

冷启动不调用 `user/info`：

```text
无Token → 登录注册入口
Token已过期 → 清Session并进入登录失效流程
Token有效但无User快照 → 登录注册入口
Token有效且User未完善 → 完善资料页
Token有效且User已完善 → Welcome或首页
```

上述目标路由在 `runApp()` 前仅根据本地数据计算。原生启动页结束后，Flutter首帧直接展示最终页面，不再显示独立的认证分流中间页；运行期 Session恢复、后台刷新和过期弹窗仍由 `AuthSessionNotifier` 负责。

## Token刷新

```text
Access Token剩余时间 >= 1天
→ 直接恢复Session，不刷新

Access Token有效且剩余时间 < 1天
→ 立即恢复Session和页面
→ 后台调用POST /api/v1/app/auth/refresh
   ├─ 成功：替换双Token和expires_at
   └─ 任意失败：保留旧Token，不Toast、不弹窗、不阻塞

Access Token已过期
→ 不调用Refresh
→ 清Session并要求重新登录
```

后台 Refresh写入前检查是否仍是同一 Session，避免旧请求覆盖退出、注销或重新登录后的状态。`1000002`、`1000016` 只属于 Refresh接口，不触发全局登录失效弹窗。

## 登录失效与业务错误码

以下 code每次都会幂等清理本地双Token、User快照和内存 Session：

```text
1000001  Access Token已过期
1000010  未授权访问
1000011  登录状态无效
1000013  账号不存在或已注销
```

全局同一时刻只展示一个登录失效弹窗。用户确认后无动画进入登录注册入口；弹窗关闭后再次收到失效 code仍会重新显示。

所有已确认服务端业务码统一维护在 `lib/core/network/api_business_code.dart`，业务代码不得直接写错误码数字。

## 用户资料与年龄确认

首次完善资料和 Profile编辑资料都调用：

```http
POST /api/v1/app/user/update
```

基础字段为 `full_name`、`birth_day`（`yyyy-MM-dd`）和 `gender`（`1=Male`、`2=Female`）。年龄最终由服务端判断：

```text
首次提交：不传age_confirm
├─ 4000105 → 只显示Under 18弹窗，不Toast、不显示页面错误文字
├─ 4000106 → 黄色提示，按钮变为Continue anyway
└─ 成功 → 使用响应User覆盖本地快照

收到4000106后再次点击Continue anyway
→ 同一份资料传age_confirm: 1
```

客户端不传 `age_confirm: 0`，也不能仅根据本地年龄主动传 `1`。修改生日、离开页面、重新登录或提交成功后清除高龄确认状态。

## 退出与注销

```text
POST /api/v1/app/auth/logout
POST /api/v1/app/auth/deactivate
```

- Log out无确认弹窗；即使服务端失败，也完成本地退出。
- Delete account先显示不可逆确认弹窗；仅在服务端成功后清理本地数据。
- 注销成功不显示成功 Toast，无动画进入登录注册入口。
- Nalo退出不会自动清除浏览器或 Shop App中的 Shopify登录 Cookie。

## 网络层

自有业务API统一使用 `ApiClient + Dio`：

- Base URL由 `AppEnvironment` 提供，当前默认测试环境。
- 连接、发送和接收超时均为30秒。
- 默认注入 `Authorization: Bearer <access_token>`；公开接口设置 `requiresAuth: false`。
- 统一解析 `{code, msg, data}`，用户提示使用服务端 `msg`。
- 动态注入 App版本、Build、平台、设备ID、Request ID、系统语言和时区Header。
- Authorization、双Token、OAuth code、code_verifier、state和 attempt ID必须脱敏。
- 当前所有构建模式为联调抓包临时绕过TLS证书校验；正式发布前必须按照 `RELEASE_CHECKLIST.md` 恢复。

环境配置位于 `lib/app/config/app_environment.dart`。

## 主要业务接口

```text
POST /api/v1/app/auth/shopify/prepare
POST /api/v1/app/auth/shopify/exchange
POST /api/v1/app/auth/refresh
POST /api/v1/app/auth/logout
POST /api/v1/app/auth/deactivate
GET  /api/v1/app/user/info
POST /api/v1/app/user/update
GET  /api/v1/app/index
GET  /api/v1/app/detections/history
GET  /api/v1/app/products
GET  /api/v1/app/products/shopify-url
GET  /api/v1/app/configs/list
POST /api/v1/app/detections
POST /api/v1/app/detections/confirm
GET  /api/v1/app/detections/result
GET  /api/v1/app/configs/version/check
```

## 首页、Shop与检测

`HomePage` 是登录后的主容器，包含 Home和 Shop两个 Tab并提供 Scan入口。

- Home通过 `/index` 获取仪表盘数据。
- Test history通过 `/detections/history` 获取历史记录。
- Shop通过 `/products` 获取商品，通过 `/products/shopify-url` 获取购买地址。
- Test flow根据 `/configs/list` 配置调用检测创建、确认和结果接口。
- Shop空商品、检测历史为空和列表加载失败统一使用 `NaloStateView`，由页面传入对应插画、文案和操作回调。
- Shop空商品使用检测盒插画；检测历史完全为空使用记录卡插画并提供 `Start a test`；列表首次加载失败共用网络错误插画和重试入口。
- 检测历史通过 `pagination.all` 区分完全无记录和筛选后无结果：完全无记录进入检测流程，筛选后无结果可返回 All。
- 从历史空状态点击 `Start a test` 上报 `test_start_entry_click`，`page_name=test_history`、`position=3`、`total_test_count=0`；检测流程返回后重新请求历史第一页。

## 版本更新

每次冷启动首次进入 Home Tab时，后台调用 `GET /api/v1/app/configs/version/check`：

- 每次进程生命周期最多检查一次。
- 不显示 Loading，不阻塞首页。
- 请求或解析失败只记录日志。
- 普通更新可稍后处理或关闭。
- 强制更新不能通过遮罩或系统返回关闭。
- 更新地址优先使用 `market_url`，其次使用 `download_url`。

详细需求见 `docs/requirements/2026-09-02-版本更新弹窗需求.md`。

## 通知权限

- App启动时读取并按现有策略请求通知权限。
- Welcome仅在没有通知权限时显示提醒入口。
- 点击启用通知时，根据权限状态请求权限或进入系统设置。
- App恢复前台后刷新通知权限状态。

## 国际化

项目保留 `lib/l10n/*.arb` 和 `lib/l10n/generated/` 国际化基础设施。当前登录注册等新增页面按阶段性要求直接在 Widget中填写设计稿英文原文，暂不通过 l10n key引用；后续恢复国际化时不手动编辑生成文件。

## Amplitude、日志与设备ID

埋点统一封装在 `lib/core/analytics/analytics.dart`：

```text
登录成功 → identifyUser
退出登录 → resetIdentity
Session失效 → resetIdentity
注销成功 → resetIdentity
```

埋点失败不得阻塞核心业务。日志统一使用项目 Logger，不新增 `print`，敏感字段必须脱敏。

Flutter通过 MethodChannel `com.rnbl.nalo/device_id` 获取 iOS或 Android设备ID。业务代码只依赖 `DeviceIdService`，不直接调用 MethodChannel。

## 开发与验证约定

- 依赖版本以 `pubspec.yaml` 为准，未确认前不调整依赖。
- 除非用户明确要求，不运行 Test、Analyze、Build、模拟器、真机或 Xcode/Gradle验证。
- 修改模块职责、流程、接口或生命周期时，同步更新代码注释、模块需求文档和本文件。
- 开发规范以 `AGENTS.md` 为准。
