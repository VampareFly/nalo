# 自有业务 API 网络层设计

## 1. 目标与范围

为自有业务后端建立独立、可维护的网络层，采用薄 `ApiClient` 封装 Dio，并通过 Riverpod 完成依赖注入。网络层统一处理公共请求上下文、响应包解析和异常转换；认证模块负责登录、Token 持久化、冷启动检查与会话状态。

本设计不修改现有 Shopify OAuth 请求链路。Shopify 客户端与自有业务 API 客户端分别配置，避免 baseUrl、鉴权和业务错误协议相互影响。

本阶段包含：

- 自有业务 API 专用 Dio 与 `ApiClient`。
- 统一响应包及异常模型。
- 公共 Header 动态注入与敏感日志脱敏。
- 邮箱登录、Refresh Token 请求及本地 Token 存储。
- 冷启动时检查 Token，并在临近过期时刷新。
- Token 已过期和服务端 Token 失效码的会话清理。

本阶段不包含：

- 定时刷新或 App 恢复前台时刷新。
- 业务请求失败后的自动刷新及请求重放。
- Shopify OAuth 网络层迁移。
- 安全存储迁移。

## 2. 已知接口协议

### 2.1 临时 Base URL

测试和生产环境暂时使用保留示例地址：

```text
https://api.example.com
```

```dart
// TODO: <pf> 后端部署地址确定后，替换自有业务 API 的 baseUrl。
```

### 2.2 邮箱登录

```http
POST /api/v1/app/auth/login
Content-Type: application/json
```

```json
{
  "email": "user@example.com",
  "password": "mySecret123"
}
```

### 2.3 刷新 Token

```http
POST /api/v1/auth/refresh
Content-Type: application/json
```

```json
{
  "refresh_token": "..."
}
```

登录和刷新请求不携带普通 Access Token，避免认证链路产生循环依赖。

### 2.4 统一响应包

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "access_token": "...",
    "refresh_token": "...",
    "expires_in": 1786087969
  }
}
```

失败响应沿用相同外层结构：

```json
{
  "code": 1000001,
  "message": "Token 已过期，请重新登录",
  "data": null
}
```

后端通过业务 `code` 表示成功或失败，HTTP 状态通常为 `200`。`code == 1000001` 表示 Token 已过期，客户端不调用 Refresh Token 接口，而是清理本地认证数据并进入未登录状态。

错误码范围：

| 范围 | 模块 |
| --- | --- |
| `1000000+` | 认证、登录、用户 |
| `2000000+` | 暂未定义 |
| `4000000+` | 参数类错误 |
| `5000000+` | 系统错误 |

## 3. 架构与职责

依赖方向：

```text
ViewModel / Provider
        ↓
    Repository
        ↓
     Service
        ↓
    ApiClient
        ↓
Dio + Interceptors
        ↓
      Backend
```

### 3.1 `core/network`

- `api_client.dart`：集中维护薄请求入口、统一响应、异常类型和脱敏日志，不解析具体业务 Model。
- `api_providers.dart`：维护公共请求上下文和 Header 拦截器，并通过 Riverpod 组装自有 API Dio、`ApiClient`、TokenStorage 及会话过期事件。

### 3.2 `features/auth`

- `auth_token.dart`：集中维护客户端 Token 模型、后端 DTO 解析与映射。
- `auth_service.dart`：声明登录、刷新接口及对应 Provider。
- `auth_repository.dart`：编排认证请求、Token 持久化及对应 Provider。
- `token_storage.dart`：定义 Token 存储协议、SharedPreferences 实现及对应 Provider。
- `auth_session_provider.dart`：维护认证会话状态，编排冷启动检查和退出登录。

`ApiClient` 不负责页面导航或 Toast；ViewModel 或应用级会话监听器根据结构化异常决定 UI 行为。

## 4. 公共 Header

需要鉴权的业务请求动态添加：

| Header | 来源 |
| --- | --- |
| `Content-Type: application/json` | Dio 默认配置 |
| `Authorization: Bearer <access_token>` | TokenStorage |
| `X-App-Version` | `package_info_plus` |
| `X-App-Build` | `package_info_plus` |
| `X-Platform` | 当前平台，值为 `ios` 或 `android` |
| `X-Device-ID` | 项目现有 DeviceIdService |
| `X-Request-ID` | 每次请求生成 UUID |
| `X-Language` | 当前应用语言，如 `zh-CN`、`en-US` |
| `X-Timezone` | 设备时区，如 `Asia/Shanghai` |

Header 值应在请求发生时获取，避免应用语言、Token 或运行上下文变化后继续使用旧缓存。登录和刷新请求显式标记为无需 Access Token，但仍可携带版本、平台、设备、请求 ID、语言和时区信息。

如果项目当前能力不能可靠生成 UUID 或读取 IANA 时区，应优先使用现有官方/项目能力；确需新增依赖时，需另行说明并获得确认。

## 5. 响应与异常处理

响应处理规则：

1. `code == 0`：将 `data` 交给对应 DTO 解析。
2. `code == 1000001`：清空本地 Token，切换为未登录状态，并抛出 `SessionExpiredException`。
3. 其他非零业务码：抛出 `ApiException(code, message, data)`。
4. 超时、断网、连接失败和请求取消：转换为分类明确的 `NetworkException`。
5. 响应缺少必要字段或字段类型错误：抛出 `ResponseFormatException`。

网络层不显示 Toast。普通业务错误的 `message` 由 ViewModel 交给页面展示；会话过期由应用级认证状态统一处理，避免多个并发请求重复导航或重复提示。

日志不得输出以下内容的明文：

- `Authorization`。
- `access_token` 和 `refresh_token`。
- 登录密码。
- 其他后续明确的敏感字段。

## 6. Token 存储模型

客户端统一模型使用 `expiresAt`，业务代码不直接依赖服务端容易产生歧义的 `expires_in` 名称。当前暂按 Unix 秒级时间戳解析：

```dart
final expiresAt = DateTime.fromMillisecondsSinceEpoch(
  expiresIn * 1000,
  isUtc: true,
);
```

```dart
// TODO: <pf> 后端 Token 过期字段确定后，调整过期时间解析规则。
```

本阶段使用 SharedPreferences 保存 Access Token、Refresh Token 和过期时间。`TokenStorage` 隔离具体实现，后续切换 Keychain/Android Keystore 等安全存储时，不改变 Repository、Service 或网络层调用方式。

SharedPreferences 不是敏感凭证的生产级安全存储；该选择属于当前阶段约束，不代表长期安全方案。

## 7. 冷启动刷新流程

应用冷启动时，由 `AuthSessionProvider` 执行一次认证恢复：

1. 从 TokenStorage 读取完整 Token。
2. Token 不完整时，按未登录状态进入应用。
3. 若 `expiresAt <= now`：
   - 清空 Access Token、Refresh Token 和过期时间；
   - 进入未登录状态；
   - 由 UI 提示用户重新登录；
   - 不调用刷新接口。
4. 若 Token 尚未过期，且剩余有效期小于或等于一天：
   - 调用刷新接口；
   - 成功时原子保存新的双 Token 和过期时间；
   - 失败时保留旧 Token，不提示用户，正常进入应用。
5. 若剩余有效期大于一天，直接恢复登录状态并进入应用。

刷新失败包括服务端非零业务码、网络异常和解析异常。只要旧 Token 仍未过期，冷启动刷新失败均保持静默；后续业务请求仍按统一响应规则处理。

```dart
// TODO: <pf> 根据产品策略，评估是否增加请求前或应用恢复前台时的主动刷新机制。
```

## 8. 登录、退出与会话过期

### 登录

1. ViewModel 调用 AuthRepository。
2. Repository 通过 AuthService 请求邮箱登录接口。
3. DTO 将响应映射为 AuthToken。
4. Repository 原子保存完整 Token。
5. AuthSessionProvider 切换为已登录状态。

### 主动退出

主动退出无条件调用 `TokenStorage.clear()`，并切换为未登录状态。

### 服务端判定 Token 过期

任意业务请求返回 `code == 1000001` 时：

1. 不调用刷新接口，也不重放原请求。
2. 清空本地 Token。
3. AuthSessionProvider 统一切换为未登录状态。
4. UI 统一提示用户重新登录。

## 9. Riverpod 与生命周期

- Dio 和 ApiClient 由应用级 Provider 管理，不使用 `autoDispose`，避免请求间重复创建客户端。
- TokenStorage 和 AuthRepository 使用单一职责 Provider 注入。
- AuthSessionProvider 负责冷启动认证恢复及会话状态，Widget 只监听状态并渲染对应路由或页面。
- 业务 Repository 依赖 ApiClient，不直接创建 Dio。
- 拦截器依赖 TokenStorage 和请求上下文服务，不反向依赖 Widget 或 ViewModel。

## 10. 测试设计

遵循项目约束，实施后不由 Codex 自动运行测试、分析、编译或构建。建议准备以下测试，由开发者决定执行时机：

- `ApiResponse` 对成功、业务失败、空 data 和格式错误的解析。
- Dio 异常到 `NetworkException` 的分类转换。
- 每个请求动态注入公共 Header。
- 登录与刷新请求不携带 Access Token。
- 日志对密码、Authorization 和双 Token 的脱敏。
- 登录成功后原子保存完整 Token。
- 冷启动无 Token、已过期、一天内过期和一天外过期四条分支。
- 冷启动刷新失败时保留尚未过期的旧 Token，且不产生 UI 提示。
- `code == 1000001` 时清理 Token，并只产生一次全局会话失效状态。
- 主动退出时清理全部认证数据。

## 11. 影响与后续演进

该设计会新增自有业务网络与认证模块，但不改变现有 Shopify OAuth 行为。Repository 只依赖稳定的 ApiClient 和认证接口，后端字段、Token 存储方式与真实 baseUrl 后续变化时，修改范围被限制在配置、DTO Mapper 或 TokenStorage 实现中。

后续可按实际需求演进：

- 将 SharedPreferences 替换为平台安全存储。
- 后端明确过期字段后调整 Token Mapper。
- 产品确认刷新策略后增加请求前或前台恢复时刷新。
- 错误码表完善后增加更细的业务异常映射。
