# Shopify 与 App 用户订单绑定接入指南

## 1. 目标

实现以下完整链路：

```text
App 用户点击商品
→ App 打开带关联 Token 的 Shopify 商品详情页
→ Shopify Theme 保存 Token
→ 用户加入购物车并完成付款
→ Shopify 订单携带关联 Token
→ Shopify Webhook 通知 App 后端
→ 后端将 Shopify 订单绑定到 App 用户
```

生产环境不应直接在 URL 中暴露 `user_id`。推荐使用后端生成的随机、短期、一次性 Token。

---

## 2. 各端职责

### App

1. 用户点击商品时调用 App 后端。
2. 后端返回带 `app_token` 的 Shopify 商品链接。
3. App 使用外部浏览器或 WebView 打开链接。
4. 用户返回 App 后，向后端查询最新订单状态。

### App 后端

1. 根据 App 登录态获取真实用户。
2. 生成一次性随机 Token，并建立 `Token → App 用户` 的映射。
3. 返回 Shopify 商品详情链接。
4. 接收并验证 Shopify Webhook。
5. 从订单中读取 Token，绑定 Shopify 订单和 App 用户。
6. 处理重复 Webhook、退款、取消等状态。

### Shopify Theme

1. 从商品链接读取 `app_token`。
2. 临时保存 Token，避免页面跳转后丢失。
3. 写入 Cart Attribute。
4. 商品加入购物车时写入 Line Item Property。

### Shopify

1. 提供商品详情、购物车、结账和支付页面。
2. 将购物车属性转移到订单。
3. 支付后发送 `orders/paid` Webhook。

---

## 3. App 打开商品页

App 向后端请求商品购买链接：

```http
POST /api/shopify/product-link
Authorization: Bearer <app_access_token>
Content-Type: application/json

{
  "product_handle": "test001-商品-标题"
}
```

后端返回：

```json
{
  "url": "https://test-store-001-55rykspg.myshopify.com/products/test001-%E5%95%86%E5%93%81-%E6%A0%87%E9%A2%98?app_token=link_xxx"
}
```

Flutter 可使用 `url_launcher`：

```dart
final uri = Uri.parse(response.data['url']);

await launchUrl(
  uri,
  mode: LaunchMode.externalApplication,
);
```

外部浏览器通常对 Shopify 登录、Shop Pay、Apple Pay 和第三方支付兼容性更好。

---

## 4. Token 设计

建议建立表：

```text
shopify_order_tokens

id
token_hash
app_user_id
product_handle
expires_at
used_at
shopify_order_id
created_at
```

要求：

- 使用安全随机值，建议至少 32 字节。
- 数据库存 Token 哈希，不保存明文。
- 有效期建议 1～24 小时。
- 不在 Token 中直接包含 App 用户 ID。
- 一个 Token 原则上只允许绑定一个订单。
- 测试阶段可以使用 `test_ppf_123`，但不能用于生产。

---

## 5. Shopify Theme 配置

进入：

```text
Shopify Admin
→ Online Store
→ Themes
→ 当前已发布主题
→ Edit code
```

创建文件：

```text
assets/app-user-link.js
```

示例代码：

```js
(() => {
  const TOKEN_PARAM = 'app_token';
  const STORAGE_KEY = 'pending_app_token';
  const PROPERTY_NAME = '_app_token';

  function readTokenFromUrl() {
    return new URLSearchParams(window.location.search).get(TOKEN_PARAM);
  }

  function getToken() {
    const token = readTokenFromUrl();

    if (token) {
      sessionStorage.setItem(STORAGE_KEY, token);
      return token;
    }

    return sessionStorage.getItem(STORAGE_KEY);
  }

  async function writeCartAttribute(token) {
    const root = window.Shopify?.routes?.root || '/';

    const response = await fetch(`${root}cart/update.js`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json'
      },
      body: JSON.stringify({
        attributes: {
          app_token: token
        }
      })
    });

    if (!response.ok) {
      throw new Error(`Cart attribute update failed: ${response.status}`);
    }
  }

  function addTokenToProductForms(token) {
    const forms = document.querySelectorAll('form[action*="/cart/add"]');

    forms.forEach((form) => {
      let input = form.querySelector(
        `input[name="properties[${PROPERTY_NAME}]"]`
      );

      if (!input) {
        input = document.createElement('input');
        input.type = 'hidden';
        input.name = `properties[${PROPERTY_NAME}]`;
        form.appendChild(input);
      }

      input.value = token;
    });
  }

  function initialize() {
    const token = getToken();

    if (!token) return;

    addTokenToProductForms(token);

    writeCartAttribute(token).catch((error) => {
      console.error('[App User Link]', error);
    });
  }

  initialize();

  const observer = new MutationObserver(() => {
    const token = sessionStorage.getItem(STORAGE_KEY);

    if (token) {
      addTokenToProductForms(token);
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
})();
```

在 `layout/theme.liquid` 的 `</body>` 前加载：

```liquid
<script src="{{ 'app-user-link.js' | asset_url }}" defer></script>
```

必须确认代码添加在用户实际访问的已发布主题中，而不是仅存在于未发布的测试主题。

---

## 6. 为什么同时写两个字段

### Cart Attribute

写入：

```json
{
  "attributes": {
    "app_token": "link_xxx"
  }
}
```

订单 Webhook 中通常表现为：

```json
{
  "note_attributes": [
    {
      "name": "app_token",
      "value": "link_xxx"
    }
  ]
}
```

用于订单级关联，也更容易在 Shopify Admin 的 `Additional details` 中查看。

### Line Item Property

写入：

```json
{
  "properties": {
    "_app_token": "link_xxx"
  }
}
```

订单 Webhook 中通常位于：

```json
{
  "line_items": [
    {
      "properties": [
        {
          "name": "_app_token",
          "value": "link_xxx"
        }
      ]
    }
  ]
}
```

用于商品级关联。字段名前缀 `_` 表示私有 Property，可能不会直接展示给顾客。

推荐双写：

- Line Item Property 作为商品级主要依据。
- Cart Attribute 作为订单级查询和兜底依据。

---

## 7. 下单前验证

测试链接：

```text
https://test-store-001-55rykspg.myshopify.com/products/test001-%E5%95%86%E5%93%81-%E6%A0%87%E9%A2%98?app_token=test_ppf_123
```

### 检查脚本是否加载

Chrome Console 执行：

```js
[...document.scripts]
  .map(script => script.src)
  .filter(src => src.includes('app-user-link'))
```

应该返回 `app-user-link.js` 的 CDN 地址。

### 检查 URL Token

```js
new URLSearchParams(location.search).get('app_token')
```

应返回：

```text
test_ppf_123
```

### 检查临时存储

```js
sessionStorage.getItem('pending_app_token')
```

应返回：

```text
test_ppf_123
```

### 检查购物车

加入购物车后、付款前，打开：

```text
https://test-store-001-55rykspg.myshopify.com/cart.js
```

必须看到：

```json
{
  "attributes": {
    "app_token": "test_ppf_123"
  }
}
```

最好同时看到：

```json
{
  "items": [
    {
      "properties": {
        "_app_token": "test_ppf_123"
      }
    }
  ]
}
```

如果 `/cart.js` 中没有 Token，订单中一定不会出现 Token，应停止支付并先排查 Theme JS。

---

## 8. Shopify Admin 查看位置

完成新订单后进入：

```text
Shopify Admin
→ Orders
→ 打开订单
```

检查以下位置：

1. 页面右侧或下方的 `Additional details`：查看 Cart Attribute。
2. 商品行项目详情：查看 Line Item Property。
3. `Notes` 不是 Cart Attribute，不要通过 `No notes from customer` 判断绑定失败。

如果 `_app_token` 未显示在 Admin，不代表 Webhook 中一定没有。最终应以订单 Webhook 或 Admin API 返回的数据为准。

测试阶段为了直观看到商品属性，可以暂时将：

```js
const PROPERTY_NAME = '_app_token';
```

改为：

```js
const PROPERTY_NAME = 'app_token';
```

测试完成后再恢复私有字段。

---

## 9. Webhook 配置

建议订阅：

```text
orders/paid
```

可选：

```text
orders/create
orders/cancelled
refunds/create
```

职责建议：

- `orders/create`：记录订单创建，不发放已付款权益。
- `orders/paid`：确认付款并正式绑定用户。
- `orders/cancelled`：更新取消状态。
- `refunds/create`：更新退款状态。

Webhook 地址示例：

```text
POST https://api.example.com/webhooks/shopify/orders-paid
```

---

## 10. Webhook 安全验证

后端必须验证：

```text
X-Shopify-Hmac-Sha256
```

计算方式：

```text
Base64(HMAC-SHA256(Shopify Webhook Secret, 原始请求体字节))
```

注意：

- 必须使用原始 HTTP Body。
- 不能先解析 JSON 再重新序列化后计算。
- 使用常量时间比较，避免时序攻击。
- HMAC 不匹配时返回 `401` 或 `403`，且不得处理订单。

---

## 11. 后端绑定逻辑

Token 提取优先级：

```text
line_items[].properties._app_token
→ 如果没有，再读取 note_attributes.app_token
```

处理流程：

```text
验证 Shopify HMAC
→ 检查 Webhook 是否重复
→ 提取 app_token
→ 计算 token_hash
→ 查询 Token 映射
→ 检查是否过期、是否已绑定
→ 校验订单商品是否匹配
→ 保存 Shopify 订单
→ 绑定 app_user_id
→ 标记 Token 已使用
→ 返回 200
```

建议在一个数据库事务中完成。

---

## 12. Webhook 幂等

Shopify 可能重复发送同一个 Webhook，不能重复发放权益。

建议保存：

```text
shopify_webhook_events

webhook_id UNIQUE
topic
shop_domain
shopify_order_id
payload
processed_at
```

优先使用：

```text
X-Shopify-Webhook-Id
```

并用以下业务唯一键兜底：

```text
shopify_order_id + webhook_topic
```

已经成功处理过的 Webhook 应直接返回 `200 OK`。

---

## 13. App 查询购买状态

浏览器支付成功不等于 App 已收到可靠的支付结果。App 返回前台后应查询后端：

```http
GET /api/me/shopify-orders/latest
Authorization: Bearer <app_access_token>
```

示例响应：

```json
{
  "order_id": "1008",
  "status": "paid",
  "product": "cortisol-test-kit",
  "bound": true
}
```

推荐刷新时机：

- App 从后台恢复。
- Home 页面重新打开。
- 用户手动下拉刷新。
- 收到推送通知。
- 支付后的短时间有限轮询。

状态建议：

```text
pending   已生成购买链接
created   Shopify 已创建订单
paid      已付款并成功绑定
cancelled 已取消
refunded  已退款
```

---

## 14. 完整验收流程

1. 使用测试 App 用户登录。
2. App 点击 Shopify 商品。
3. 后端创建 Token 并返回商品链接。
4. 确认 URL 包含 `app_token`。
5. 确认 Theme 加载 `app-user-link.js`。
6. 将商品加入购物车。
7. 打开 `/cart.js`，确认 Cart Attribute 和 Property。
8. 使用 Shopify 测试支付完成新订单。
9. 在 Admin 查看 `Additional details`。
10. 检查 `orders/paid` Webhook 原始 JSON。
11. 确认后端验证 HMAC 成功。
12. 确认后端找到正确的 `app_user_id`。
13. 确认 Shopify Order 与 App 用户绑定。
14. 返回 App，确认订单状态和购买权益更新。
15. 重放同一个 Webhook，确认没有重复处理。
16. 测试取消和退款后的状态更新。

---

## 15. 常见问题排查

### URL 有 Token，但订单没有

原因通常是 Theme JS 没有加载、执行报错，或写入购物车失败。先检查 `/cart.js`，不要直接重复付款。

### Admin 没看到字段

- 检查是否存在 `Additional details`。
- `_app_token` 可能作为私有 Property 不直接显示。
- 以 Webhook 或 Admin API 数据为最终依据。

### 修改 Theme 后旧订单仍没有字段

Theme 修改不会补充历史订单，必须清空购物车后重新创建新订单。

### 使用 Buy Now、Shop Pay 或 Apple Pay

动态结账可能绕过普通 Add to Cart 的部分主题逻辑。必须分别测试：

- 普通 Add to cart。
- Buy now。
- Shop Pay。
- Apple Pay / Google Pay。

MVP 阶段可以先关闭动态结账按钮，只开放已验证的普通购物车链路。

### App 外部浏览器和桌面浏览器结果不一致

它们可能使用不同 Cookie 和购物车会话。必须在实际 App 打开的浏览器会话中完成从商品页到支付的完整流程。

---

## 16. 隐私与安全注意事项

不要向 Shopify 写入：

- 密码或 App Access Token。
- 医疗检测结果。
- 出生日期和健康数据。
- 不必要的手机号、邮箱或身份信息。
- 可被猜测的连续用户 ID。

推荐仅写入无业务含义的关联标识：

```text
app_reference=ref_8f1c2a...
```

由 App 后端内部完成：

```text
app_reference → app_user_id
```

同时应记录必要的审计日志，但日志中也不要输出完整生产 Token。

---

## 17. 上线前检查清单

- [ ] Theme JS 位于已发布主题。
- [ ] 商品详情 URL 能正确读取 Token。
- [ ] `/cart.js` 存在 Cart Attribute。
- [ ] `/cart.js` 存在 Line Item Property。
- [ ] 普通购物车结账链路通过。
- [ ] 动态结账链路已验证或已关闭。
- [ ] Webhook HMAC 验证已启用。
- [ ] Webhook 幂等已实现。
- [ ] Token 随机、短期、一次性。
- [ ] Token 数据库存哈希。
- [ ] 商品与 Token 的预期商品已校验。
- [ ] 退款和取消能够同步。
- [ ] App 返回前台后从后端查询订单状态。
- [ ] Shopify 中不保存健康数据和不必要的个人信息。

