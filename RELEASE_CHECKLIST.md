# Nalo Release Checklist

## 使用规则

本文件是 Nalo 安装包和正式版本的统一发布检查入口。

- 每次生成对外测试包、Profile 包或 Release 包前必须阅读本文件。
- 每次正式上线前必须逐项执行代码检查并勾选阻断项。
- 检查项描述的是目标发布包，不得以本地 Debug 包正常作为上线依据。
- 任一标记为“阻断”的检查未完成时，不得发布 Production 包。
- 当前只维护环境配置模块；签名、权限、第三方服务等模块后续按相同结构补充。

## 发布信息

- 版本号：
- Build Number：
- 目标环境：Test / Production
- 安装包类型：Debug / Profile / Release
- 执行人：
- 检查日期：

## 上线阻断项

- [ ] 上传 App Store 或 Google Play 前，已再次确认是否保留摇一摇环境切换入口。
- [ ] 若保留摇一摇入口，已确认正式包不会误连接 Test 环境或泄露测试数据。
- [ ] Production 包的 `defaultEnvironment` 已改为 `AppEnvironment.production`。
- [ ] 已确认目标环境与 API Base URL 一致。
- [ ] Google Play 构建已显式传入 `ALLOW_NETWORK_INSPECTION=false`。
- [ ] Production 包没有写死 Charles、Proxyman 或其他代理地址。
- [ ] Production 包没有携带测试抓包 CA。
- [ ] 自有业务 Dio 和 Shopify Dio 均已通过构建开关恢复系统默认 TLS 校验。

任一项未完成，禁止发布 Production 包。

---

## 1. 环境配置

### 1.1 API Base URL

#### 上线要求

| 环境 | Base URL |
| --- | --- |
| Test | `https://api-test.naloresults.com/` |
| Production | `https://api.naloresults.com/` |

环境配置文件：

```text
lib/app/config/app_environment.dart
```

#### 代码检查

确认环境枚举映射正确：

```dart
AppEnvironment.test => 'https://api-test.naloresults.com/',
AppEnvironment.production => 'https://api.naloresults.com/',
```

确认首次安装使用的默认环境；正式上线必须设置为 Production：

```dart
const defaultEnvironment = AppEnvironment.production;
```

搜索所有可能写死的服务端地址：

```bash
rg -n "api-test\.naloresults\.com|api\.naloresults\.com|api\.example\.com" lib
```

#### 人工检查

- [ ] Test 包使用 Test Base URL。
- [ ] Production 包使用 Production Base URL。
- [ ] Production 包的首次安装默认环境为 `AppEnvironment.production`。
- [ ] Repository 和 Service 中没有自行写死其他业务 API Host。
- [ ] Production 包没有连接 Test 后端。

#### 阻断规则

Production Base URL 不正确时，禁止发布。

### 1.2 HTTPS 证书与抓包配置

#### 当前临时状态

当前所有构建模式默认允许 HTTPS 抓包，包括：

- Debug。
- Profile。
- Release。
- 自有业务 API 使用的 Dio。
- Shopify Service 使用的 Dio。

当前配置位于：

```text
lib/core/network/dio_provider.dart
lib/core/network/api_providers.dart
```

核心临时代码：

```dart
client.badCertificateCallback = (certificate, host, port) => true;
```

该配置会接受任意无法通过系统信任链验证的证书，只能用于当前接口联调。正式包保留该配置会产生中间人攻击风险，可能泄露 Access Token、Refresh Token 和用户业务数据。

#### Google Play 构建操作

抓包能力由编译期常量 `ALLOW_NETWORK_INSPECTION` 控制，默认值为 `true`。Google Play
构建必须显式传入：

```bash
flutter build appbundle --dart-define=ALLOW_NETWORK_INSPECTION=false
```

关闭后不会读取 Android 系统代理，也不会安装自定义 `IOHttpClientAdapter`，自有业务 Dio
和 Shopify Dio 都使用系统默认 TLS 校验。该值是编译期常量，运行时无法由用户重新开启。

#### 全项目搜索检查

执行：

```bash
rg -n "badCertificateCallback|configureCertificateBypass|findProxy|IOHttpClientAdapter|SecurityContext" lib android ios
```

代码允许保留统一抓包实现，但必须确认：

```text
ALLOW_NETWORK_INSPECTION 默认值：true
Google Play 构建参数：ALLOW_NETWORK_INSPECTION=false
写死代理 IP 或端口：0 处
测试 SecurityContext / 测试 CA：0 处
```

检查 Android 是否信任用户 CA 或允许明文流量：

```bash
rg -n "networkSecurityConfig|certificates src=\"user\"|usesCleartextTraffic|cleartextTrafficPermitted" android
```

Production 要求：

- 不得信任用户安装的抓包 CA。
- 不得携带 Charles、Proxyman 或其他测试 CA。
- 不得开启明文 HTTP 流量。

#### 人工检查

- [ ] Google Play 构建命令包含 `--dart-define=ALLOW_NETWORK_INSPECTION=false`。
- [ ] 已确认关闭开关时自有业务 Dio 不安装抓包 Adapter。
- [ ] 已确认关闭开关时 Shopify Dio 不安装抓包 Adapter。
- [ ] 没有写死代理 IP 或端口。
- [ ] Android Production 配置不信任用户 CA。
- [ ] Production 包不包含测试抓包证书。

#### 阻断规则

Google Play 构建未显式关闭 `ALLOW_NETWORK_INSPECTION` 时，禁止发布。

### 1.3 代理配置

#### 当前规则

项目不写死 Charles、Proxyman 等代理地址。允许抓包的 Android 构建从当前系统网络读取
代理；关闭 `ALLOW_NETWORK_INSPECTION` 后不读取或应用系统代理。

#### 代码检查

搜索写死的代理配置：

```bash
rg -n "findProxy|PROXY |proxyHost|proxyPort|8888|9090" lib android ios
```

#### 人工检查

- [ ] Production 代码没有写死代理 Host。
- [ ] Production 代码没有写死代理端口。
- [ ] Production 配置不依赖开发电脑局域网地址。

#### 阻断规则

Production 中存在写死代理配置时，禁止发布。

---

## 后续待补充模块

以下模块尚未纳入本次清单，后续新增上线配置时继续使用“上线要求 → 代码操作 → 搜索检查 → 人工检查 → 阻断规则”的结构：

- 版本号与 Build Number。
- Android / iOS 正式签名。
- 权限和隐私声明。
- Firebase、Amplitude、Shopify 等第三方环境。
- 日志、埋点与 Crashlytics。
- 商店上传与灰度发布。
- 回滚与应急处理。

## 发布记录

| 版本 | Build | 环境 | 包类型 | 执行人 | 日期 | 结果 | 备注 |
| --- | ---: | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |  |
