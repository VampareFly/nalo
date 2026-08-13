# 自有业务 API 网络层实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为自有后端实现独立的 Dio 网络层、统一响应与异常、邮箱登录、本地 Token 会话以及冷启动刷新。

**Architecture:** 业务 ViewModel 依赖 AuthRepository，Repository 通过 AuthService 和薄 ApiClient 请求后端。Riverpod 负责组装 Dio、请求上下文、TokenStorage 与认证会话；Shopify OAuth 保持现状。

**Tech Stack:** Flutter、Dart 3.12、Dio 5、Riverpod 3、SharedPreferences、package_info_plus、flutter_timezone 5.1。

## Global Constraints

- 仅新增 `flutter_timezone: ^5.1.0`，不升级或修改其他依赖版本。
- 临时 Base URL 为 `https://api.example.com`，并保留 `<pf>` TODO。
- `expires_in` 暂按 Unix 秒级时间戳解析，并保留 `<pf>` TODO。
- 业务码 `1000001` 表示 Token 已过期：清空本地 Token，不刷新、不重放请求。
- 冷启动时仅当 Token 尚未过期且剩余时间不超过一天才尝试刷新；失败时静默保留旧 Token。
- Token 已过期时清空本地认证数据并进入未登录状态。
- SharedPreferences 仅是当前阶段实现，须通过 TokenStorage 抽象隔离。
- 不修改现有 ShopifyAuthService 与其 Dio 行为。
- 新增类、Provider、Service、对外方法和扩展方法使用简短中文注释；核心文件包含职责与调用流说明。
- 不在网络层显示 Toast 或导航；UI 只消费结构化状态或异常。
- 不新增 `print`，日志使用现有 `loggerProvider` 并脱敏。
- Codex 实施时不运行测试、analyze、build、run 或任何 Git 命令。

---

## 文件结构

**新增网络文件**

- `lib/core/network/api_response.dart`：统一响应包。
- `lib/core/network/api_exception.dart`：业务、网络、格式和会话异常。
- `lib/core/network/api_client.dart`：薄请求入口与统一解析。
- `lib/core/network/request_context.dart`：公共 Header 数据及 UUID v4 生成。
- `lib/core/network/request_context_interceptor.dart`：动态注入公共 Header 与 Token。
- `lib/core/network/network_log_interceptor.dart`：请求/响应日志脱敏。
- `lib/core/network/business_api_provider.dart`：自有 API Dio 与 ApiClient 的 Riverpod 组装。

**新增认证文件**

- `lib/features/auth/models/auth_token.dart`：客户端 Token 模型。
- `lib/features/auth/models/auth_token_dto.dart`：服务端字段映射。
- `lib/features/auth/storage/token_storage.dart`：Token 存储协议。
- `lib/features/auth/storage/preferences_token_storage.dart`：SharedPreferences 实现。
- `lib/features/auth/services/auth_service.dart`：登录与刷新请求。
- `lib/features/auth/repositories/auth_repository.dart`：认证编排与持久化。
- `lib/features/auth/providers/auth_providers.dart`：认证依赖 Provider。
- `lib/features/auth/providers/auth_session_provider.dart`：冷启动会话状态。

**修改文件**

- `pubspec.yaml`：新增 flutter_timezone。
- `lib/app/config/app_environment.dart`：增加业务 API Base URL。
- `lib/features/onboarding/view_models/login_view_model.dart`：接入真实邮箱登录并增加 loading。
- `lib/features/onboarding/presentation/pages/login_page.dart`：移除 Device ID 调试逻辑，消费登录 loading/错误。
- `lib/app/app.dart`：启动认证恢复并统一监听会话过期提示。

**新增测试文件（只编写，不由 Codex 执行）**

- `test/core/network/api_client_test.dart`
- `test/core/network/request_context_interceptor_test.dart`
- `test/features/auth/auth_token_dto_test.dart`
- `test/features/auth/preferences_token_storage_test.dart`
- `test/features/auth/auth_repository_test.dart`
- `test/features/auth/auth_session_provider_test.dart`

---

### Task 1: 统一响应与异常模型

**Files:**
- Create: `lib/core/network/api_response.dart`
- Create: `lib/core/network/api_exception.dart`
- Test: `test/core/network/api_client_test.dart`

**Interfaces:**
- Produces: `ApiResponse<T>.fromJson(Map<String,dynamic>, T Function(Object?)?)`、`ApiException`、`NetworkException`、`ResponseFormatException`、`SessionExpiredException`。

- [ ] **Step 1: 编写统一响应解析失败测试**

覆盖 `code/message/data` 正常解析，以及缺少 code、code 非 int、message 非 String 时抛出 `ResponseFormatException`。

```dart
test('parses a successful envelope', () {
  final response = ApiResponse<Map<String, dynamic>>.fromJson(
    {'code': 0, 'message': 'success', 'data': {'id': 1}},
    (data) => data! as Map<String, dynamic>,
  );
  expect(response.code, 0);
  expect(response.data, {'id': 1});
});
```

- [ ] **Step 2: 实现模型**

`ApiResponse<T>` 仅验证外层结构并调用可选 decoder；`ApiException` 保存 `code/message/data`；`NetworkExceptionType` 至少包含 timeout、connection、cancelled、unknown。

- [ ] **Step 3: 由开发者手动验证**

```bash
flutter test test/core/network/api_client_test.dart
```

预期：统一响应模型相关测试通过。

### Task 2: Token 模型与 SharedPreferences 存储

**Files:**
- Create: `lib/features/auth/models/auth_token.dart`
- Create: `lib/features/auth/models/auth_token_dto.dart`
- Create: `lib/features/auth/storage/token_storage.dart`
- Create: `lib/features/auth/storage/preferences_token_storage.dart`
- Test: `test/features/auth/auth_token_dto_test.dart`
- Test: `test/features/auth/preferences_token_storage_test.dart`

**Interfaces:**
- Produces: `AuthToken(accessToken, refreshToken, expiresAt)`、`AuthTokenDto.fromJson().toModel()`、`TokenStorage.read/save/clear`。

- [ ] **Step 1: 编写 DTO 与存储测试**

```dart
test('maps expires_in as a Unix-seconds timestamp', () {
  final token = AuthTokenDto.fromJson({
    'access_token': 'access',
    'refresh_token': 'refresh',
    'expires_in': 1786087969,
  }).toModel();
  expect(token.expiresAt.millisecondsSinceEpoch, 1786087969000);
});
```

存储测试覆盖完整读写、任一字段缺失返回 null、`clear()` 删除三个字段。

- [ ] **Step 2: 实现 Token 类型与 Mapper**

在 `toModel()` 的 `expires_in` 转换旁写入：

```dart
// TODO: <pf> 后端 Token 过期字段确定后，调整过期时间解析规则。
```

- [ ] **Step 3: 实现存储抽象**

```dart
abstract interface class TokenStorage {
  Future<AuthToken?> read();
  Future<void> save(AuthToken token);
  Future<void> clear();
}
```

SharedPreferences 保存 ISO-8601 UTC `expiresAt`；先写三个值后再对外返回，读取不完整时视为无会话。

- [ ] **Step 4: 由开发者手动验证**

```bash
flutter test test/features/auth/auth_token_dto_test.dart test/features/auth/preferences_token_storage_test.dart
```

### Task 3: 公共请求上下文和 Header 拦截器

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/network/request_context.dart`
- Create: `lib/core/network/request_context_interceptor.dart`
- Test: `test/core/network/request_context_interceptor_test.dart`

**Interfaces:**
- Consumes: `TokenStorage.read()`。
- Produces: `RequestContextLoader.load()` 与 `RequestContextInterceptor`；通过 `RequestOptions.extra['requiresAuth'] == false` 跳过 Authorization。

- [ ] **Step 1: 新增唯一依赖**

```yaml
flutter_timezone: ^5.1.0
```

- [ ] **Step 2: 编写 Header 测试**

覆盖版本、构建号、平台、设备 ID、请求 ID、语言、IANA 时区和 Authorization；覆盖登录/刷新请求不加 Authorization；验证不同请求生成不同 UUID。

- [ ] **Step 3: 实现请求上下文**

用 `PackageInfo`、`DeviceIdService`、`FlutterTimezone.getLocalTimezone().identifier` 和当前 Locale 构建上下文。UUID v4 使用 `Random.secure()` 生成 16 字节并正确设置 version/variant bit，不新增 uuid 依赖。

- [ ] **Step 4: 实现拦截器**

`onRequest` 每次动态读取上下文和 Token；所有请求添加公共 Header，只有 `requiresAuth != false` 且存在 Token 时添加 Bearer Header。

- [ ] **Step 5: 由开发者手动验证**

```bash
flutter pub get
flutter test test/core/network/request_context_interceptor_test.dart
```

### Task 4: 自有 API 的 ApiClient、日志和 Provider

**Files:**
- Modify: `lib/app/config/app_environment.dart`
- Create: `lib/core/network/api_client.dart`
- Create: `lib/core/network/network_log_interceptor.dart`
- Create: `lib/core/network/business_api_provider.dart`
- Modify: `test/core/network/api_client_test.dart`

**Interfaces:**
- Produces: `ApiClient.get/post/put/delete<T>(..., decoder, requiresAuth)` 与 `businessApiClientProvider`。

- [ ] **Step 1: 增加环境地址**

测试与生产先返回 `https://api.example.com`，并在 getter 上保留：

```dart
// TODO: <pf> 后端部署地址确定后，替换自有业务 API 的 baseUrl。
```

- [ ] **Step 2: 编写 ApiClient 测试**

覆盖 code 0 返回 data、1000001 先调用会话过期回调再抛异常、其他非零码抛 ApiException、格式错误和 Dio 各类异常映射。

- [ ] **Step 3: 实现 ApiClient**

四个 HTTP 方法委托一个私有 `_request<T>`。响应必须是 JSON object；解析统一外层后，`code == 0` 调 decoder，`1000001` 调注入的 `Future<void> Function()` 清理回调并抛 `SessionExpiredException`。

- [ ] **Step 4: 实现脱敏日志**

复制 headers/data 后递归替换 `authorization`、`password`、`access_token`、`refresh_token` 的值为 `***`，再交给项目 Logger；不修改真实请求对象。

- [ ] **Step 5: 组装业务 Dio**

配置 JSON Content-Type、15 秒连接/发送/接收超时、环境 baseUrl，并按请求上下文→脱敏日志顺序添加拦截器。`ref.onDispose(dio.close)`。

- [ ] **Step 6: 由开发者手动验证**

```bash
flutter test test/core/network/api_client_test.dart
```

### Task 5: AuthService 与 AuthRepository

**Files:**
- Create: `lib/features/auth/services/auth_service.dart`
- Create: `lib/features/auth/repositories/auth_repository.dart`
- Create: `lib/features/auth/providers/auth_providers.dart`
- Test: `test/features/auth/auth_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient.post`、`AuthTokenDto`、`TokenStorage`。
- Produces: `AuthRepository.login(email,password)`、`refresh(currentToken)`、`readToken()`、`clearSession()`。

- [ ] **Step 1: 编写 Repository 测试**

覆盖登录 body 精确为 email/password、刷新 body 精确为 refresh_token、两者均传 `requiresAuth: false`、成功后保存完整新 Token、失败时不覆盖旧 Token。

- [ ] **Step 2: 实现 AuthService**

登录调用 `/api/v1/app/auth/login`，刷新调用 `/api/v1/auth/refresh`，均用 `AuthTokenDto.fromJson` 解码并跳过 Access Token。

- [ ] **Step 3: 实现 Repository**

登录与刷新只在请求和解析均成功后调用 `TokenStorage.save()`；刷新失败自然向上抛出且保留旧值。`clearSession()` 委托 `TokenStorage.clear()`。

- [ ] **Step 4: 创建 Providers**

从现有 `sharedPreferencesProvider.future` 创建异步 TokenStorage；据此创建 AuthRepository。避免 Provider 循环依赖，会话清理回调只依赖 TokenStorage。

- [ ] **Step 5: 由开发者手动验证**

```bash
flutter test test/features/auth/auth_repository_test.dart
```

### Task 6: 冷启动认证会话

**Files:**
- Create: `lib/features/auth/providers/auth_session_provider.dart`
- Test: `test/features/auth/auth_session_provider_test.dart`

**Interfaces:**
- Produces: `AuthSessionState`（loading/authenticated/unauthenticated/sessionExpired）与 `AuthSessionNotifier.restoreSession/logout/markExpired`。

- [ ] **Step 1: 编写启动状态测试**

固定注入 `Clock`/`DateTime Function()`，覆盖：无 Token；已过期时 clear 且不 refresh；剩余恰好一天时 refresh；大于一天不 refresh；刷新成功认证；刷新业务/网络/格式失败均保留旧 Token 并认证成功。

- [ ] **Step 2: 实现状态与 Notifier**

`restoreSession()` 只运行一次：先 loading，再按设计文档四分支更新状态。判断统一使用 UTC。刷新异常只要旧 Token 未过期就静默转 authenticated，不在 Provider 显示 Toast。

- [ ] **Step 3: 实现会话失效去重**

`markExpired()` 若已经 unauthenticated/sessionExpired 则直接返回；否则先 clear，再设置一次 sessionExpired，供 UI 统一提示。

- [ ] **Step 4: 由开发者手动验证**

```bash
flutter test test/features/auth/auth_session_provider_test.dart
```

### Task 7: 登录页与应用启动接入

**Files:**
- Modify: `lib/features/onboarding/view_models/login_view_model.dart`
- Modify: `lib/features/onboarding/presentation/pages/login_page.dart`
- Modify: `lib/app/app.dart`

**Interfaces:**
- Consumes: `AuthRepository.login()`、`AuthSessionNotifier.restoreSession/markExpired`。
- Produces: 真实邮箱登录与全局会话过期提示。

- [ ] **Step 1: 更新 LoginState**

增加 `isLoading`，保留密码可见状态；重复提交时直接返回 null。登录校验保持现状，真实请求成功后才调用 `markFirstInstallationCompleted()`，异常 message 作为页面 Toast 文案返回。

- [ ] **Step 2: 更新 LoginPage**

删除临时 Device ID 读取和日志；登录中禁用按钮或忽略重复提交，继续由页面显示登录错误。检查并同步现有文件职责注释；不改无关布局。

- [ ] **Step 3: 接入冷启动恢复**

在应用根部监听 AuthSessionProvider，并在初始化阶段触发一次 `restoreSession()`。`sessionExpired` 只提示一次“请重新登录”，具体路由跳转使用现有 GoRouter，不让 Provider 依赖 BuildContext。

- [ ] **Step 4: 手动检查清单**

不执行命令；开发者重点检查：冷启动不会重复刷新、未过期刷新失败无提示、1000001 清理本地 Token、登录失败只出现一次 Toast、Shopify 登录不受影响。

### Task 8: 最终静态审阅（不运行验证）

**Files:**
- Review: 所有本计划新增和修改文件。

- [ ] **Step 1: 注释一致性检查**

检查所有新增公开类型/API 有简短中文注释；核心文件头说明职责、调用流与生命周期；既有文件头和公开 API 注释与新行为一致。

- [ ] **Step 2: 范围检查**

确认没有修改 ShopifyAuthService、没有升级其他依赖、没有无关重构、没有 `print`、没有在网络层调用 Toast/路由。

- [ ] **Step 3: 安全与协议检查**

确认密码和 Token 不进入日志；1000001 不触发 refresh；过期 Token 会 clear；一天内刷新失败保留旧 Token；两个 `<pf>` TODO 保留。

- [ ] **Step 4: 向用户交付**

列出修改文件、逐文件内容、修改原因、潜在影响和 Flutter 学习点，并明确说明未执行测试、分析、编译或运行。
